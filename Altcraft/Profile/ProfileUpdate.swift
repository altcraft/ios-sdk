//
//  ProfileUpdate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

internal actor ProfileUpdate {

    static let shared = ProfileUpdate()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: ProfileUpdate"
    }

    /// Registers a profile fields update operation and starts queued delivery.
    ///
    /// - Parameters:
    ///   - profileFields: Encoded profile fields to update.
    ///   - skipTriggers: If `true`, skips company triggers for this update.
    func updateProfileFields(
        profileFields: Data?,
        skipTriggers: Bool = false
    ) async {
        let function = getFunc(#function)
        let env = Environment.create()
        
        do {
            try env.checkCoreDataError()
            let userTag = try await env.userTag()
            
            switch await addProfileUpdateEntity(
                userTag: userTag,
                profileFields: profileFields,
                skipTriggers: skipTriggers
            ) {
            case .success:
                RetryCounters.shared.reset(
                    RetryKey.profileUpdate
                )
                
                await self.enqueueStart()
                
            case .failure(let error):
                errorEvent(function, error: error)
            }
        } catch {
            errorEvent(function, error: error)
        }
    }
    
    /// Enqueues profile update processing into the serial command queue.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func enqueueStart(enableRetry: Bool = true) async {
        let function = getFunc(#function)
        ProfileUpdateQueues.startQueue.submit {
            do {
                await NetworkMonitor.shared.waitConnected()
                
                let env = Environment.create()
                let userTag = try await env.userTag()
                let result = await self.processUpdates(
                    userTag: userTag
                )
                
                if !result && enableRetry {
                    profileUpdateRetry()
                }
            } catch {
                retryEvent(function, error: error)
                if enableRetry {
                    profileUpdateRetry()
                }
            }
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
    fileprivate func processUpdates(userTag: String) async -> Bool {
        let context = CoreDataManager.shared.getContext()

        await clearOldProfileUpdates(context: context)

        let updates = await getAllProfileUpdatesByTag(
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
            return retryEvent(function, error: profileUpdateRequestDataIsNil)
        }

        guard let request = profileUpdateRequest(data: requestData) else {
            return retryEvent(function, error: nonJsonObject)
        }
        
        return await RequestManager.shared.sendRequest(
            request: request, requestName: Constants.RequestName.profileUpdate
        )
    }
}


// MARK: - Unit Test Hooks

/// Extension exposing internal test hooks for unit tests.
extension ProfileUpdate {
    
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
    internal func test_profile_update_processUpdates(
        userTag: String
    ) async -> Bool {
        await processUpdates(userTag: userTag)
    }
}
