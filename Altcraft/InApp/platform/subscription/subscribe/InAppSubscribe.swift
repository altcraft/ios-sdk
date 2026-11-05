//
//  InAppSubscribe.swift
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

/// A singleton actor responsible for in-app subscription requests and managing subscription-related tasks.
@available(iOSApplicationExtension, unavailable)
internal actor InAppSubscriptionProcess {

    static let shared = InAppSubscriptionProcess()
    let backgroundTask = AccessToBackground.shared

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: inAppSubscribe"
    }

    /**
     Submits a subscribe request. If another subscription is currently being processed,
     this call is enqueued and executed after the current one completes.

     - Parameters:
       - status: The status value ("subscribed", "unsubscribed", "suspended") to associate with the subscription.
       - sync: Synchronization flag — `true` for synchronous server processing, `false` for asynchronous.
       - profileFields: Optional key–value data with profile fields to be stored with the subscription.
       - customFields: Optional key–value data with user-defined fields for segmentation/personalization.
       - cats: Optional list of categories to apply (`[CategoryData]`).
       - replace: If `true`, existing subscription data will be replaced with the new one.
       - skipTriggers: If `true`, automation triggers (e.g., autoresponders) will be skipped.
     */
    func inAppSubscribe(
        status: String,
        sync: Bool,
        profileFields: Data? = nil,
        customFields: Data? = nil,
        cats: Data? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) async {
        await backgroundTask.accessToBackground()
        let initGate = await InitBarrier.shared.current()

        await withInitReady(
            function: #function, gate: initGate
        ) {
            let env = InAppEnvironment.fresh()

            do {
                try env.checkCoreDataError()
                let userTag = try await env.userTag()
                let auth = try await env.internalAuth()

                guard await CoreEnvironmentProvider.isAuth()
                else {
                    InAppLog.error(
                        #function,error: CoreEvents.notAuthenticatedError
                    )
                    return
                }

                // Merge device + AppInfo fields into custom fields (Android
                // MapBuilder.unionMaps semantics): device fields + AppInfo are
                // resolved internally by MapBuilder from the Core environment;
                // caller only passes user-defined fields.
                var unionedCustomFields = customFields
                if let customFields, !customFields.isEmpty {
                    let parsed = decodeAnyMap(customFields) ?? [:]
                    let merged = await MapBuilder.unionMaps(parsed)
                    unionedCustomFields = encodeAnyMap(merged)
                }

                switch await InAppSubscribeDAO.addInAppSubscribeEntity(
                    userTag: userTag,
                    deviceId: auth.deviceId,
                    acid: auth.currentAcid,
                    status: status,
                    sync: sync,
                    profileFields: profileFields,
                    customFields: unionedCustomFields,
                    cats: cats,
                    replace: replace,
                    skipTriggers: skipTriggers
                ) {
                case .success:
                    RetryCounters.shared.reset(
                        InAppConstants.RetryKey.inAppSubscribe
                    )

                    await InAppSubscriptionWorker.shared.processPending()

                case .failure(let err):
                    InAppLog.error(#function, error: err)
                }
            } catch {
                InAppLog.error(#function, error: error)
            }
        }
    }

    /// Enqueues subscription processing into the serial command queue.
    ///
    /// Ensures only one processing run is active at a time by scheduling the job
    /// on the internal queue. The run waits for connectivity, then processes all queued
    /// subscriptions from Core Data.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    ///                          If `false`, no retry is scheduled.
    func enqueueStart(enableRetry: Bool = true) async {
       let function = getFunc(#function)
       InAppSubscribeQueues.startQueue.submit {
            let env = InAppEnvironment.fresh()

            do {
                await NetworkMonitor.shared.waitConnected()

                let userTag = try await env.userTag()
                let result = await self.processSubscriptions(
                    userTag: userTag
                )

                if !result && enableRetry {
                    inAppSubscribeRetry()
                }
            } catch {
                InAppLog.retry(function, error: error)
                if enableRetry { inAppSubscribeRetry() }
            }
        }
    }

    /// Processes all stored subscriptions for the given user tag.
    ///
    /// Performs cleanup of outdated entities, fetches all queued subscriptions for
    /// `userTag`, and processes them sequentially. Returns early if processing
    /// should stop and be retried later.
    ///
    /// - Parameter userTag: Tag used to fetch subscription entities.
    /// - Returns: `true` if all queued subscriptions were processed to completion;
    ///            `false` if processing stopped and should be retried later.
    fileprivate func processSubscriptions(userTag: String) async -> Bool {
        let context = inAppDatabase.getContext()
        await InAppSubscribeDAO.clearOldInAppSubscriptions(context: context)

        let subscriptions = await InAppSubscribeDAO.getAllInAppSubscriptionsByTag(
            context: context, userTag: userTag
        )

        for subscription in subscriptions {

            if await isRetry(context: context, subscription: subscription) {
                return false
            }
        }

        return true
    }

    /// Handles a single subscription entity: decides whether to retry or finish.
    ///
    /// For `RetryEvent`, applies retry-limit logic (`retryLimit`) and decides
    /// whether processing should stop and retry later.
    /// For `ErrorEvent`, deletes the entity.
    /// For success, saves in-app subscription state and deletes the entity.
    ///
    /// - Parameters:
    ///   - context: The managed object context for Core Data operations.
    ///   - subscription: Subscription to process (`NSManagedObjectID`).
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        subscription: NSManagedObjectID,
    ) async -> Bool {
        let response = await request(context: context, objectID: subscription)

        if !(response is ErrorEvent) {
            await setInAppSubStatus(context: context, objectID: subscription)
        }

        switch response {
        case is RetryEvent:
            return !(await retryLimit(context: context, objectID: subscription))
        default:
            return !(await deleteEntity(context: context, objectID: subscription))
        }
    }

    /// Executes the subscription flow for a single stored entity, including request preparation and network submission.
    ///
    /// Builds request payload from Core Data, resolves request name based on status, and sends
    /// the request via `RequestManager`.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to fetch payload for the request.
    ///   - objectID: The `NSManagedObjectID` of the stored subscription entity.
    /// - Returns: `Event` describing success / retry / error.
    fileprivate func request(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async  -> Event {
        let function = getFunc(#function)
        guard let data = await getInAppSubscribeRequestData(
            context: context, objectID: objectID
        ) else {
            return InAppLog.retry(
                function, error: InAppModuleEvents.subscribeRequestDataIsNil
            )
        }

        guard let request = await inAppSubscribeRequest(data: data) else {
            return InAppLog.retry(
                function, error: CoreEvents.failedCreateRequest
            )
        }

        return await RequestManager.shared.sendRequest(
            request: request, requestData: data
        ).event
    }

    /// Saves in-app subscription state for the current SDK user.
    ///
    /// PushStatusProcess is taken from the stored `InAppSubscribeEntity`.
    /// The current user tag is taken from internal auth. If a state for the same
    /// user tag already exists, it is updated instead of creating a duplicate.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to read subscription data.
    ///   - objectID: `NSManagedObjectID` of the processed `InAppSubscribeEntity`.
    fileprivate func setInAppSubStatus(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async {
        do {
            let env = InAppEnvironment.fresh()
            let auth = try await env.internalAuth()

            guard let userTag = auth.currentUserTag else {
                return
            }

            guard let status = try await context.performAsync({
                (try context.existingObject(
                    with: objectID
                ) as? InAppSubscribeEntity)?.status
            }) else {
                return
            }

            switch await InAppSubStateDAO.setInAppSubStateEntity(
                userTag: userTag,
                status: status
            ) {
            case .success:
                return

            case .failure(let error):
                InAppLog.error(#function, error: error)
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Returns in-app subscription status for the current SDK user.
    ///
    /// Returns `false` when:
    /// - current user tag is missing;
    /// - authenticated user tag does not match active SDK user tag;
    /// - subscription state for the current user tag is missing;
    /// - saved status is not `"subscribed"`;
    /// - reading state fails.
    ///
    /// - Returns: `true` only when saved state for the current user has status `"subscribed"`.
    func getInAppSubscriptionStatus() async -> Bool {
        do {
            let env = InAppEnvironment.fresh()
            let userTag = try await env.userTag()
            let auth = try await env.internalAuth()

            guard let authUserTag = auth.currentUserTag else {
                return false
            }

            guard userTag == authUserTag else {
                return false
            }

            let context = inAppDatabase.getContext()
            let status = await InAppSubStateDAO.getInAppSubStateStatus(
                userTag: authUserTag,
                context: context
            )

            return status == InAppConstants.SubStatus.subscribed
        } catch {
            InAppLog.error(#function, error: error)
            return false
        }
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing fileprivate subscription-processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension InAppSubscriptionProcess {

    /// Test hook for internal request flow of a single subscription.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - objectID: `NSManagedObjectID` of the `InAppSubscribeEntity`.
    /// - Returns: Resulting `Event`.
    internal func test_inApp_subscribe_request(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async -> Event {
        await request(context: context, objectID: objectID)
    }

    /// Test hook for processing a single subscription.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - subscription: `NSManagedObjectID` of the `InAppSubscribeEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    internal func test_inApp_subscribe_isRetry(
        context: NSManagedObjectContext,
        subscription: NSManagedObjectID
    ) async -> Bool {
        await isRetry(context: context, subscription: subscription)
    }

    /// Test hook for processing queued subscriptions by user tag.
    ///
    /// - Parameter userTag: User tag used to fetch queued subscriptions.
    /// - Returns: `true` if processing completes without retry stop, otherwise `false`.
    internal func test_inApp_subscribe_processSubscriptions(
        userTag: String
    ) async -> Bool {
        await processSubscriptions(userTag: userTag)
    }
}
