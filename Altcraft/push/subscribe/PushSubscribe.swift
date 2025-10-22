//
//  PushSubscribe.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UserNotifications
import UIKit
import CoreData

/// A singleton class responsible for push subscription requests and managing subscription-related tasks.
internal class PushSubscribe: NSObject {
    
    static let shared = PushSubscribe()
    let userDefault = StoredVariablesManager.shared
    let backgroundTask = AccessToBackground.shared
    
    private func retry() {
        requestRetry(request: Constants.FunctionsCode.SS)
        SubscribeQueues.startQueue.reset(dropCurrent: true)
    }
    
    /// Result type to control next step in subscription processing.
    private enum RequestResult {
        case completed
        case retry
    }
    
    /**
     Submits a subscribe request. If another subscription is currently being processed,
     this call is enqueued and executed after the current one completes.
     
     - Parameters:
      - status:The status value ("subscribed", "unsubscribed", "suspended") to associate with the subscription.
      - sync: A sync identifier used to track the invocation or version of the operation.
      - customFields: Optional key-value data with user-defined fields for advanced segmentation or personalization.
      - cats: Optional map of category identifiers and boolean flags indicating selection status.
      - replace: If `true`, existing subscription data will be replaced with the new one.
      - skipTriggers: If `true`, automation triggers (e.g., autoresponders) will be skipped.
     */
    func pushSubscribe(
        status: String,
        sync: Int,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        self.backgroundTask.accessToBackground()
        SubscribeQueues.entityQueue.submit { done in
            guard !self.userDefault.getDbErrorStatus() else {
                errorEvent(#function, error: coreDataError)
                done()
                return
            }
            
            getUserTag { userTag in
                guard let userTag = userTag else {
                    errorEvent(#function, error: userTagIsNilE)
                    done()
                    return
                }
                
                if customFields.containsNonPrimitiveValues() {
                    errorEvent(#function, error: fieldsIsObjects)
                    done()
                    return
                }
                
                addSubscribeEntity(
                    userTag: userTag,
                    status: status,
                    sync: sync,
                    profileFields: profileFields,
                    customFields: customFields,
                    cats: cats,
                    replace: replace,
                    skipTriggers: skipTriggers,
                    uid: UUID().uuidString
                ) { result in
                    switch result {
                    case .success:
                        subRetryCount = 0
                        self.enqueueStart()
                        done()
                    case .failure(let err):
                        errorEvent(#function, error: err)
                        done()
                    }
                }
            }
        }
    }

    /// Enqueues a subscription processing job into the serial command queue.
    /// Creates a fresh background context via `getContext()` and starts a single
    /// `startSubscribe` run. The queue guarantees that only one run executes at a time;
    /// the queue is released only after the whole flow completes.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure
    ///                          (e.g., no permission/network). If `false`, no retry is scheduled.
    func enqueueStart(enableRetry: Bool = true) {
        SubscribeQueues.startQueue.submit { done in
            self.startSubscribe(context: getContext(), enableRetry: enableRetry) {
                done()
            }
        }
    }
    
    /// Starts the full subscription processing flow using the shared Core Data context.
    ///
    /// This method validates whether:
    /// - Push notifications are authorized
    /// - The SDK is initialized
    ///
    /// If both conditions pass, the subscription flow proceeds.
    /// Otherwise, a retry event is triggered and the completion is called.
    ///
    /// - Parameters:
    ///   - context: Optional managed object context. If not provided, a shared background context is used.
    ///   - completion: Closure called after the operation completes.
    func startSubscribe(
        context: NSManagedObjectContext,
        enableRetry: Bool = true,
        completion: @escaping () -> Void = {}
    ) {
        NetworkMonitor.shared.performActionWhenConnected {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus != .authorized {
                    retryEvent(#function, error: permissionDenied)
                    if enableRetry { self.retry() }
                    return SubscribeQueues.syncQueue.async {
                        completion()
                    }
                }
                
                self.processSubscriptions(context: context) { completed in
                    if !completed && enableRetry {
                        self.retry()
                    }
                    SubscribeQueues.syncQueue.async {
                        completion()
                    }
                }
            }
        }
    }
    
    /// Processes all stored subscriptions using the provided Core Data context.
    /// If no subscriptions are found, completes immediately. Triggers retry logic if any subscription fails.
    ///
    /// - Parameters:
    ///   - context: A Core Data context to use for fetching and deleting subscription records.
    ///   - completion: A closure returning `true` if processing succeeded without retry, or `false` otherwise.
    func processSubscriptions(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        getUserTag { userTag in
            guard let tag = userTag else {
                errorEvent(#function, error: userTagIsNil)
                return completion(true)
            }
            getAllSubscriptionsByTag(context: context, userTag: tag) { subscriptions in
                
                guard !subscriptions.isEmpty else { return completion(true) }
                
                self.signAll(context: context, subscriptions: subscriptions) { retry in
                    completion(!retry)
                }
            }
        }
    }
    
    /// Processes a list of subscription entities sequentially.
    ///
    /// Each subscription is sent using `subscribeProcess`, followed by either
    /// `handleRetryEvent` or `handleSuccessEvent`. Stops early if a retry is needed.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for operations.
    ///   - subscriptions: Subscriptions to process.
    ///   - completion: Called with `true` if retry is needed, `false` otherwise.
    func signAll(
        context: NSManagedObjectContext,
        subscriptions: [NSManagedObjectID],
        completion: @escaping (Bool) -> Void
    ) {
        var index = 0
        func processNext() {
            guard index < subscriptions.count else { return completion(false) }
            
            let subscription = subscriptions[index]
            
            index += 1
            
            self.handleSubscription(context: context, event: subscription) { result in
                result == .completed ? processNext() : completion(true)
            }
        }
        processNext()
    }
    
    /// Handles a single subscription: decides whether to continue or retry.
    ///
    /// - Parameters:
    ///   - context: The managed object context for Core Data operations.
    ///   - subscription: Subscription to process.
    ///   - completion: Called with `.continue` to proceed or `.retry` to abort with retry.
    private func handleSubscription(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        completion: @escaping (RequestResult) -> Void
    ) {
        
        self.sendSubscribeRequest(context: context, objectID: event) { result in
            if result is RetryEvent {
                subscribeLimit(context: context, for: event){ limit in completion(limit ? .completed : .retry) }
                return
            }
            deleteSubscriptions(context: context, objectID: event) { deleted in completion(deleted ? .completed : .retry) }
        }
    }
    
    /// Executes the subscription flow for a single entity, including request preparation and network submission.
    ///
    /// - Parameters:
    ///   - entity: A `SubscribeEntity` representing stored subscription details.
    ///   - completion: Closure called with the resulting `Event` (success, failure, or retry event).
    func sendSubscribeRequest(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID,
        completion: @escaping (Event) -> Void
    ) {
        getSubscribeRequestData(context: context, objectID: objectID) { data in
            guard let data = data else {
                completion(retryEvent(#function, error: subscribeRequestDataIsNil))
                return
            }
            guard let request = subscribeRequest(data: data) else {
                completion(retryEvent(#function, error: failedCreateRequest))
                return
            }
            RequestManager.shared.sendRequest(
                request: request, requestName: Constants.RequestName.subscribe, completion: completion
            )
        }
    }
}
