//
//  ProfileUpdate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

internal actor ProfileUpdateProcess {

    static let shared = ProfileUpdateProcess()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: ProfileUpdateProcess"
    }

    /// Registers a profile fields update operation and starts queued delivery.
    ///
    /// Waits for SDK initialization to complete before reading the user tag
    /// (Android parity, `submitSdkCommand` with `initAwait = true`), so an
    /// update submitted before `initialization` is processed once the
    /// configuration is installed instead of being dropped.
    ///
    /// - Parameters:
    ///   - profileFields: Encoded profile fields to update.
    ///   - skipTriggers: If `true`, skips company triggers for this update.
    func updateProfileFields(
        profileFields: Data?,
        skipTriggers: Bool = false
    ) async {
        guard SerialCommandQueue.isCurrent() else { return }
        let function = getFunc(#function)
        let initGate = await InitBarrier.shared.current()

        await withInitReady(function: function, gate: initGate) {
            let env = ProfileEnvironment.fresh()

            do {
                try env.checkCoreDataError()
                let userTag = try await env.userTag()

                switch await ProfileUpdateDAO.addProfileUpdateEntity(
                    userTag: userTag,
                    profileFields: profileFields,
                    skipTriggers: skipTriggers
                ) {
                case .success:
                    guard SerialCommandQueue.isCurrent() else { return }
                    RetryCounters.shared.reset(
                        ProfileConstants.RetryKey.profileUpdate
                    )

                    await ProfileUpdateWorker.shared.processPending()

                case .failure(let error):
                    ProfileLog.error(function, error: error)
                }
            } catch {
                ProfileLog.error(function, error: error)
            }
        }
    }

    /// Enqueues profile update processing into the serial command queue.
    ///
    /// - Parameters:
    ///   - enableRetry: If `true`, schedules internal retry on failure.
    ///   - awaitCompletion: If `true` and the device is currently online, the
    ///     call awaits the completion of the queued run (background refresh
    ///     path). Offline the run stays enqueued fire-and-forget — the call
    ///     returns immediately and the job waits for connectivity itself.
    func enqueueStart(
        enableRetry: Bool = true,
        awaitCompletion: Bool = false
    ) async {
        guard SerialCommandQueue.isCurrent() else { return }
        let function = getFunc(#function)
        let handle = ProfileUpdateQueues.startQueue.submit {
            do {
                await NetworkMonitor.shared.waitConnected()
                guard SerialCommandQueue.isCurrent() else { return }

                let env = ProfileEnvironment.fresh()
                let userTag = try await env.userTag()
                let result = try await self.processUpdates(
                    userTag: userTag
                )

                if SerialCommandQueue.isCurrent() && !result && enableRetry {
                    profileUpdateRetry()
                }
            } catch {
                ProfileLog.retry(function, error: error)
                if SerialCommandQueue.isCurrent() && enableRetry {
                    profileUpdateRetry()
                }
            }
        }

        if awaitCompletion, await NetworkMonitor.shared.isOnline() {
            await handle.value
        }
    }

    /// Processes all stored profile updates for the given user tag.
    ///
    /// Performs cleanup of outdated entities, fetches all queued updates for
    /// `userTag`, and processes them sequentially. Returns early if processing
    /// should stop and be retried later.
    ///
    /// - Parameter userTag: Tag used to fetch profile update entities.
    /// - Returns: `true` if all queued updates were processed to completion;
    ///            `false` if processing stopped and should be retried later.
    /// - Throws: Rethrows fetch errors so the caller can schedule a retry;
    ///   a failed read is not treated as an empty queue.
    fileprivate func processUpdates(userTag: String) async throws -> Bool {
        let context = profileDatabase.getContext()

        await ProfileUpdateDAO.clearOldProfileUpdates(context: context)

        let updates = try await ProfileUpdateDAO.getAllProfileUpdatesByTag(
            context: context,
            userTag: userTag
        )

        for update in updates {
            if await isRetry(context: context, update: update) {
                return false
            }
        }

        return true
    }

    /// Processes a single profile update and determines whether a retry is required.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - update: `NSManagedObjectID` of the `ProfileUpdateEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        update: NSManagedObjectID
    ) async -> Bool {
        let response = await request(context: context, update: update)

        switch response {
        case is RetryEvent:
            return !(await retryLimit(context: context, objectID: update))
        default:
            return !(await deleteEntity(context: context, objectID: update))
        }
    }

    /// Builds and sends a profile update request based on the provided object ID.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to read update fields for the request.
    ///   - update: `NSManagedObjectID` of `ProfileUpdateEntity` used to create the request.
    /// - Returns: Resulting `Event` (success, failure, or retry).
    fileprivate func request(
        context: NSManagedObjectContext,
        update: NSManagedObjectID
    ) async -> Event {
        let function = getFunc(#function)
        guard let requestData = await getProfileUpdateRequestData(
            context: context,
            objectID: update
        ) else {
            return ProfileLog.retry(
                function, error: ProfileModuleEvents.profileUpdateRequestDataIsNil
            )
        }

        guard let request = await profileUpdateRequest(data: requestData) else {
            return ProfileLog.retry(function, error: CoreEvents.failedCreateRequest)
        }

        return await RequestManager.shared.sendRequest(
            request: request, requestData: requestData
        ).event
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing internal test hooks for unit tests.
extension ProfileUpdateProcess {

    /// Test hook for internal request flow of a single profile update.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - update: `NSManagedObjectID` of the `ProfileUpdateEntity`.
    /// - Returns: Resulting `Event`.
    internal func test_profile_update_request(
        context: NSManagedObjectContext,
        update: NSManagedObjectID
    ) async -> Event {
        await request(context: context, update: update)
    }

    /// Test hook for processing a single profile update.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - update: `NSManagedObjectID` of the `ProfileUpdateEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    internal func test_profile_update_processUpdate(
        context: NSManagedObjectContext,
        update: NSManagedObjectID
    ) async -> Bool {
        await isRetry(context: context, update: update)
    }

    /// Test hook for processing queued profile updates by user tag.
    ///
    /// - Parameter userTag: User tag used to fetch queued updates.
    /// - Returns: `true` if processing completes without retry stop, otherwise `false`.
    /// - Throws: Rethrows fetch errors from the underlying queue read.
    internal func test_profile_update_processUpdates(
        userTag: String
    ) async throws -> Bool {
        try await processUpdates(userTag: userTag)
    }
}
