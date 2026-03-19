//
//  PushSubscribe.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UserNotifications
import CoreData

/// A singleton actor responsible for push subscription requests and managing subscription-related tasks.
@available(iOSApplicationExtension, unavailable)
internal actor PushSubscribe {
    
    static let shared = PushSubscribe()
    let userDefault = StoredVariablesManager.shared
    let backgroundTask = AccessToBackground.shared
    
    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: pushSubscribe"
    }

    /**
     Submits a subscribe request. If another subscription is currently being processed,
     this call is enqueued and executed after the current one completes.

     - Parameters:
       - status: The status value ("subscribed", "unsubscribed", "suspended") to associate with the subscription.
       - sync: A sync identifier used to track the invocation or version of the operation.
       - profileFields: Optional key–value data with profile fields to be stored with the subscription.
       - customFields: Optional key–value data with user-defined fields for segmentation/personalization.
       - cats: Optional list of categories to apply (`[CategoryData]`).
       - replace: If `true`, existing subscription data will be replaced with the new one.
       - skipTriggers: If `true`, automation triggers (e.g., autoresponders) will be skipped.
     */
    func pushSubscribe(
        status: String,
        sync: Int,
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
            let env = Environment.create()

            do {
                try env.checkCoreDataError()
                let userTag = try await env.userTag()

                switch await addSubscribeEntity(
                    userTag: userTag,
                    status: status,
                    sync: sync,
                    profileFields: profileFields,
                    customFields: customFields,
                    cats: cats,
                    replace: replace,
                    skipTriggers: skipTriggers
                ) {
                case .success:
                    RetryCounters.shared.reset(
                        RetryKey.subscribe
                    )
                    
                    await self.enqueueStart()
                    
                case .failure(let err):
                    errorEvent(#function, error: err)
                }
            } catch {
                errorEvent(#function, error: error)
            }
        }
    }
    
    /// Enqueues subscription processing into the serial command queue.
    ///
    /// Ensures only one processing run is active at a time by scheduling the job
    /// on the internal queue. The run waits for connectivity, optionally performs
    /// token update (if auth is configured), and then processes all queued
    /// subscriptions from Core Data.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    ///                          If `false`, no retry is scheduled.
    func enqueueStart(enableRetry: Bool = true) async {
       let function = getFunc(#function)
       SubscribeQueues.startQueue.submit {
            let env = Environment.create()
            
            do {
                await NetworkMonitor.shared.waitConnected()
                
                let config = try await env.config()
                let userTag = try await env.userTag()
                
                if let rToken = config.rToken, !rToken.isEmpty {
                    if !(await TokenUpdate.shared.tokenUpdate()) {
                        if enableRetry{ pushSubscribeRetry() }
                        return
                    }
                }
                
                let result = await self.processSubscriptions(
                    userTag: userTag
                )
                
                if !result && enableRetry {
                    print("retry_1")
                    pushSubscribeRetry()
                }
            } catch {
                retryEvent(function, error: error)
                if enableRetry { pushSubscribeRetry() }
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
        let context = CoreDataManager.shared.getContext()
        await clearOldSubscriptions(context: context)
        
        let subscriptions = await getAllSubscriptionsByTag(
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
    /// For success, stores the current token if no saved token exists yet and
    /// deletes the entity.
    ///
    /// - Parameters:
    ///   - context: The managed object context for Core Data operations.
    ///   - subscription: Subscription to process (`NSManagedObjectID`).
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        subscription: NSManagedObjectID,
    ) async -> Bool {
        let function = getFunc(#function)
        let response = await request(context: context, objectID: subscription)
        
        switch response {
        case is RetryEvent: return !(await retryLimit(context: context, objectID: subscription))
        case is ErrorEvent: return !(await deleteEntity(context: context, objectID: subscription))
        default:
            let env = Environment.create()
            do {
                let token = try await env.token()
                
                if env.savedToken() == nil {
                    userDefault.setCurrentToken(provider: token.provider, token: token.token)
                }
                return !(await deleteEntity(context: context, objectID: subscription))
            } catch {
                retryEvent(function, error: error)
                return true
            }
        }
    }

    /// Executes the subscription flow for a single stored entity, including request preparation and network submission.
    ///
    /// Builds request payload from Core Data, resolves request name based on status, checks notification permission
    /// when subscribing, and sends the request via `RequestManager`.
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
        guard let data = await getSubscribeRequestData(
            context: context, objectID: objectID
        ) else {
            return retryEvent(
                function, error: subscribeRequestDataIsNil
            )
        }

        let requestName = switch data.status {
        case Constants.SubStatus.suspended: Constants.RequestName.suspend
        case Constants.SubStatus.subscribed: Constants.RequestName.subscribe
        case Constants.SubStatus.unsubscribed: Constants.RequestName.unsubscribe
        default: Constants.RequestName.subscribe
        }
    
        guard let request = pushSubscribeRequest(data: data) else {
            return retryEvent(
                function, error: failedCreateRequest
            )
        }
        
        if data.status == Constants.SubStatus.subscribed,
           !(await notificationsAuthorized()) {
            return retryEvent(
                function, error: permissionDenied
            )
        }
    
        return await RequestManager.shared.sendRequest(
            request: request, requestName: requestName
        )
    }
    
    /// Returns `true` if the user has authorized notifications.
    ///
    /// Uses `UNUserNotificationCenter` to read current notification settings.
    func notificationsAuthorized() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(
                    returning: settings.authorizationStatus == .authorized
                )
            }
        }
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing fileprivate subscription-processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension PushSubscribe {
    
    /// Test hook for internal request flow of a single subscription.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - objectID: `NSManagedObjectID` of the `SubscribeEntity`.
    /// - Returns: Resulting `Event`.
    internal func test_push_subscribe_request(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async -> Event {
        await request(context: context, objectID: objectID)
    }

    /// Test hook for processing a single subscription.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - subscription: `NSManagedObjectID` of the `SubscribeEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    internal func test_push_subscribe_isRetry(
        context: NSManagedObjectContext,
        subscription: NSManagedObjectID
    ) async -> Bool {
        await isRetry(context: context, subscription: subscription)
    }

    /// Test hook for processing queued subscriptions by user tag.
    ///
    /// - Parameter userTag: User tag used to fetch queued subscriptions.
    /// - Returns: `true` if processing completes without retry stop, otherwise `false`.
    internal func test_push_subscribe_processSubscriptions(
        userTag: String
    ) async -> Bool {
        await processSubscriptions(userTag: userTag)
    }
}
