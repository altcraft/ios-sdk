//
//  MobileEvent.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

class MobileEvent: NSObject {
    
    static let shared = MobileEvent()
    let userDefault = StoredVariablesManager.shared
    
    private func retry() {
        requestRetry(request: Constants.FunctionsCode.ME)
        MobileEventQueues.startQueue.reset(dropCurrent: true)
    }
    
    /// Result type to control next step in mobile event  processing.
    private enum RequestResult {
        case completed
        case retry
    }

    /// Sends a mobile event to the server (iOS stub).
    ///
    /// Prepares and triggers delivery of a mobile event composed of
    /// mandatory identifiers and optional metadata. This stub only declares
    /// the API surface; implement networking/queueing later.
    ///
    /// - Parameters:
    ///   - context: Application context holder (e.g. `UIApplication.shared` or custom app object).
    ///   - sid: The string ID of the pixel.
    ///   - altcraftClientID: Altcraft client identifier.
    ///   - eventName: Event name.
    ///   - sendMessageId: Send Message ID (SMID).
    ///   - payloadFields: Arbitrary event payload; will be serialized to JSON.
    ///   - matching: Optional matching pair (key, value) to be serialized to JSON.
    ///   - profileFields: Optional profile fields; will be serialized to JSON.
    ///   - subscription: Subscription to attach to the profile (`EmailSubscription` / `SmsSubscription` / `PushSubscription` / `CcDataSubscription`).
    ///   - matchingType: Type of matching (e.g., `"push_sub"`, `"email"`, etc.).
    ///   - utmTags: Optional UTM tags for campaign attribution (e.g. `source`, `medium`,`campaign`, `term`, `content`)
    ///    If provided, they are encoded and persisted with the event for downstream analytics.
    func sendMobileEvent(
        sid: String,
        eventName: String,
        sendMessageId: String? = nil,
        payloadFields: [String: Any?]? = nil,
        matching: [String: Any?]? = nil,
        profileFields: [String: Any?]? = nil,
        subscription: (any Subscription)? = nil,
        altcraftClientID: String = "",
        matchingType: String? = nil,
        utmTags: UTM? = nil
    ) {
        MobileEventQueues.entityQueue.submit { done in
            guard !self.userDefault.getDbErrorStatus() else {
                errorEvent(#function, error: coreDataError)
                done()
                return
            }
            
            getUserTag { userTag in
                guard let userTag else {
                    errorEvent(#function, error: userTagIsNilE)
                    done()
                    return
                }
                
                if payloadFields.containsNonPrimitiveValues() {
                    errorEvent(#function, error: fieldsIsObjects)
                    done()
                    return
                }
                
                let timeZone = DeviceInfo().getTimeZone()
                
                addMobileEventEntity(
                    userTag: userTag,
                    timeZone: timeZone,
                    sid: sid,
                    eventName: eventName,
                    altcraftClientID: altcraftClientID,
                    payload: payloadFields,
                    matching: matching,
                    profileFields: profileFields,
                    subscription: subscription,
                    sendMessageId: sendMessageId,
                    matchingType: matchingType,
                    utmTags: utmTags
                ) { result in
                    switch result {
                    case .success:
                        mobileEventRetryCount = 0
                        self.enqueueStart()
                        done()
                    case .failure(let error):
                        errorEvent(#function, error: error)
                        done()
                    }
                }
            }
        }
    }
    
    /// Enqueues the mobile event processing job into the serial start queue.
    /// Creates a fresh background context via `getContext()` and starts a single
    /// `startEventsSend` run. The queue guarantees that only one run executes at a time;
    /// the queue is released only after the whole flow completes.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure
    ///                          (e.g., network unavailable). If `false`, no retry is scheduled.
    func enqueueStart(enableRetry: Bool = true) {
        MobileEventQueues.startQueue.submit { done in
            self.startEventsSend(context: getContext(), enableRetry: enableRetry) {
                done()
            }
        }
    }
    
    /// Starts full mobile event processing flow using the shared Core Data context.
    ///
    /// Unlike push subscriptions, this method does not require notification authorization.
    /// It only validates network connectivity and processes all pending events.
    ///
    /// - Parameters:
    ///   - context: Optional Core Data context; if `nil`, the shared background context is used.
    ///   - completion: Closure called after processing completes (success or retry scheduled).
    func startEventsSend(
        context: NSManagedObjectContext,
        enableRetry: Bool = true,
        completion: @escaping () -> Void = {}
    ) {
        NetworkMonitor.shared.performActionWhenConnected {
            self.processEvents(context: context) { completed in
                if !completed && enableRetry {
                    self.retry()
                }
                MobileEventQueues.syncQueue.async {
                    completion()
                }
            }
        }
    }
    
    /// Fetches and processes all stored mobile events for the current user tag.
    /// Performs storage maintenance (clearing old records), then processes events sequentially.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for fetch/update/delete operations.
    ///   - completion: Closure called with `true` on overall success (no retry needed),
    ///                 or `false` if a retry should be scheduled.
    private func processEvents(context: NSManagedObjectContext, completion: @escaping (Bool) -> Void) {
        getUserTag { userTag in
            guard let tag = userTag else {
                errorEvent(#function, error: userTagIsNil)
                return completion(true)
            }
            clearOldMobileEvents(context: context) {
                getAllMobileEventsByTag(context: context, userTag: tag) { events in
                    
                    guard !events.isEmpty else { return completion(true) }
                    
                    self.sendAll(context: context, events: events) { retry in
                        completion(!retry)
                    }
                }
            }
        }
    }
    
    /// Processes multiple stored mobile events sequentially in FIFO order.
    /// Stops early if a retry condition occurs.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence updates (retry counters, deletions).
    ///   - events: Array of `NSManagedObjectID` for `MobileEventEntity` to process (FIFO).
    ///   - completion: Closure called with `true` if a retry is required (flow should stop),
    ///                 or `false` when all events have been processed successfully.
    private func sendAll(
        context: NSManagedObjectContext,
        events: [NSManagedObjectID],
        completion: @escaping (Bool) -> Void
    ) {
        var index = 0
        func processNext() {
            guard index < events.count else { completion(false); return }
            let event = events[index]
            index += 1
            self.handleEvent(context: context, event: event) { result in
                result == .completed ? processNext() : completion(true)
            }
        }
        processNext()
    }
    
    /// Handles a single mobile event: builds DTO, sends request, and resolves result.
    /// Increments retry counters or deletes the entity depending on the outcome.
    ///
    /// - Parameters:
    ///   - context: Core Data context to update retry counters or delete on success.
    ///   - event: `NSManagedObjectID` of `MobileEventEntity` to be sent.
    ///   - completion: Closure called with `.continue` to proceed with next item,
    ///                 or `.retry` to stop the flow and schedule a retry.
    private func handleEvent(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        completion: @escaping (RequestResult) -> Void
    ) {
        self.sendMobileEventRequest(context: context, event: event) { result in
            if result is RetryEvent {
                retryLimit(context: context, for: event) { limit in completion(limit ? .completed : .retry) }
                return
            }
            deleteEntity(context: context, objectID: event) { deleted in completion(deleted ? .completed : .retry) }
        }
    }
    
    /// Builds and sends a multipart mobile event request based on the provided objectID.
    /// Resolves `MobileEventRequestData` from Core Data, converts it to multipart request, and sends it.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to read event fields for the request.
    ///   - event: `NSManagedObjectID` of `MobileEventEntity` used to create the request.
    ///   - completion: Closure called with the resulting `Event` (success, failure, or retry).
    func sendMobileEventRequest(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        completion: @escaping (Event) -> Void
    ) {
        getMobileEventRequestData(context: context, objectID: event) { data in
            guard let requestData = data else {
                completion(retryEvent(#function, error: mobileRequestDataIsNil))
                return
            }
            guard let request = createMobileEventRequest(data: requestData) else {
                completion(retryEvent(#function, error: failedCreateRequest))
                return
            }
            
            RequestManager().sendRequest(
                request: request,
                requestName: Constants.RequestName.mobileEvent,
                name: requestData.eventName,   
                completion: completion
            )
        }
    }
}
