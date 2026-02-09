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
@available(iOSApplicationExtension, unavailable)
internal class PushSubscribe: NSObject {
    
    static let shared = PushSubscribe()
    let userDefault = StoredVariablesManager.shared
    let backgroundTask = AccessToBackground.shared
    
    private func retry() {
        localPushSubscribeRetry()
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
       - status: The status value ("subscribed", "unsubscribed", "suspended") to associate with the subscription.
       - sync: A sync identifier used to track the invocation or version of the operation.
       - profileFields: Optional key–value data with profile fields to be stored with the subscription.
       - customFields: Optional key–value data with user-defined fields for segmentation/personalization. Must contain only primitive values.
       - cats: Optional list of categories to apply (`[CategoryData]`).
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
        let initGate = InitBarrier.shared.current()
        SubscribeQueues.entityQueue.submit { done in
            withInitReady(function: #function, gate: initGate) {
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
                        skipTriggers: skipTriggers
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
              getConfig { configuration in
                  let start: () -> Void = {
                      self.startSubscribe(context: getContext(), enableRetry: enableRetry) {
                          done()
                      }
                  }
                  guard let rToken = configuration?.rToken, !rToken.isEmpty else {
                      start()
                      return
                  }
                  
                  TokenUpdate.shared.tokenUpdate { update in
                      if update {
                          start()
                          return
                      }

                      if enableRetry {
                          self.retry()
                      }
                      done()
                  }
              }
          }
      }

    /// Starts the full subscription processing flow using the provided Core Data context.
    /// Waits for network connectivity, then proceeds with processing.
    /// If processing indicates retry, a retry event can be scheduled.
    ///
    /// - Parameters:
    ///   - context: Managed object context to use for the operation.
    ///   - enableRetry: If `true`, schedules internal retry on failure (e.g., network/processing failures).
    ///   - completion: Closure called after the operation completes (always invoked on `SubscribeQueues.syncQueue`).
    func startSubscribe(
        context: NSManagedObjectContext,
        enableRetry: Bool = true,
        completion: @escaping () -> Void = {}
    ) {
        NetworkMonitor.shared.performActionWhenConnected {
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
            clearOldSubscriptions(context: context) {
                getAllSubscriptionsByTag(context: context, userTag: tag) { subscriptions in
                    
                    guard !subscriptions.isEmpty else { return completion(true) }
                    
                    self.signAll(context: context, subscriptions: subscriptions) { retry in
                        completion(!retry)
                    }
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
            
            self.handleSubscription(context: context, subscription: subscription) { result in
                result == .completed ? processNext() : completion(true)
            }
        }
        processNext()
    }
        
    /// Handles a single subscription: decides whether to finish or retry.
    ///
    /// - Parameters:
    ///   - context: The managed object context for Core Data operations.
    ///   - subscription: Subscription to process (`NSManagedObjectID`).
    ///   - completion: Called with `.completed` to proceed to the next item or `.retry` to abort and schedule a retry.
    private func handleSubscription(
        context: NSManagedObjectContext,
        subscription: NSManagedObjectID,
        completion: @escaping (RequestResult) -> Void
    ) {
        self.sendSubscribeRequest(context: context, objectID: subscription) { result in
            
            switch result {

            case is RetryEvent:
                retryLimit(context: context, for: subscription){
                    limit in completion(limit ? .completed : .retry)
                }
                
            case is ErrorEvent:
                deleteEntity(context: context, objectID: subscription) {
                    deleted in completion(deleted ? .completed : .retry)
                }

            default:
                TokenManager.shared.getCurrentToken { currentToken in
                    guard let currentToken = currentToken else {
                        errorEvent(#function, error: pushTokenIsNil)
                        completion(.retry)
                        return
                    }

                    self.userDefault.setCurrentToken(
                        provider: currentToken.provider,
                        token: currentToken.token
                    )

                    deleteEntity(context: context, objectID: subscription) {
                        deleted in completion(deleted ? .completed : .retry)
                    }
                }
            }
        }
    }

    /// Executes the subscription flow for a single stored entity, including request preparation and network submission.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to fetch payload for the request.
    ///   - objectID: The `NSManagedObjectID` of the stored subscription entity.
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
            
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus != .authorized &&
                   data.status == Constants.SubStatus.subscribed.rawValue {
                    completion(retryEvent(#function, error: permissionDenied))
                    return
                }
                
                guard let request = subscribeRequest(data: data) else {
                    completion(retryEvent(#function, error: failedCreateRequest))
                    return
                }
                
                let requestName = switch data.status {
                case Constants.SubStatus.suspended.rawValue: Constants.RequestName.suspend
                case Constants.SubStatus.subscribed.rawValue: Constants.RequestName.subscribe
                case Constants.SubStatus.unsubscribed.rawValue: Constants.RequestName.unsubscribe
                default:Constants.RequestName.subscribe
                }
                
                RequestManager.shared.sendRequest(
                    request: request, requestName: requestName, completion: completion
                )
            }
        }
    }
}
