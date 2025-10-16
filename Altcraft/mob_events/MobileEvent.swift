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
    
    /// Centralized background context for all subscription-related Core Data operations.
    private lazy var context: NSManagedObjectContext = {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        ctx.name = Constants.ContextName.pushSubscribe
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }()
    
    private func retry() {
        requestRetry(request: Constants.FunctionsCode.ME)
        MobileEventQueues.startQueue.reset(dropCurrent: true)
    }

    private enum SignResult {
        case `continue`
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

                self.context.perform {
                    let timeZone = DeviceInfo().getTimeZoneForMobEvent()

                    addMobileEventEntity(
                        context: self.context,
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
                            self.enqueueStart(context: self.context)
                            done()
                        case .failure(let error):
                            errorEvent(#function, error: error)
                            done()
                        }
                    }
                }
            }
        }
    }
    
    /// Enqueues the mobile event processing job into the serial start queue.
    /// Guarantees that only one `startEventsSend` execution runs at a time,
    /// and the queue is released only after the whole flow completes.
    /// - Parameter context: Optional Core Data context to use for processing.
    ///   If `nil`, the shared background context of `MobileEvent` will be used.
    func enqueueStart(context: NSManagedObjectContext?) {
        MobileEventQueues.startQueue.submit { done in
            self.startEventsSend(context: context) {
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
        context: NSManagedObjectContext? = nil,
        enableRetry: Bool = true,
        completion: @escaping () -> Void = {}
    ) {
        NetworkMonitor.shared.performActionWhenConnected {
            self.processEvents(context: context ?? self.context) { success in
                if !success && enableRetry {
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
    private func processEvents(
        context: NSManagedObjectContext,
        completion: @escaping (Bool) -> Void
    ) {
        getUserTag { userTag in
            guard let tag = userTag else {
                errorEvent(#function, error: userTagIsNil)
                completion(true)
                return
            }

            clearOldMobileEvents(context: context) {
                getAllMobileEvents(context: context, userTag: tag) { events in
                    guard !events.isEmpty else {
                        completion(true)
                        return
                    }

                    self.signAll(context: context, events: events) { retry in
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
    ///   - events: Array of `MobileEventEntity` to process.
    ///   - completion: Closure called with `true` if a retry is required (flow should stop),
    ///                 or `false` when all events have been processed successfully.
    private func signAll(
        context: NSManagedObjectContext,
        events: [MobileEventEntity],
        completion: @escaping (Bool) -> Void
    ) {
        context.perform {
            var index = 0
            func processNext() {
                guard index < events.count else {
                    completion(false)
                    return
                }
                let event = events[index]
                index += 1

                self.handleEvent(context: context, event: event) { result in
                    result == .continue ? processNext() : completion(true)
                }
            }
            processNext()
        }
    }

    /// Handles a single mobile event: builds DTO, sends request, and resolves result.
    /// Increments retry counters or deletes the entity depending on the outcome.
    ///
    /// - Parameters:
    ///   - context: Core Data context to update retry counters or delete on success.
    ///   - event: The `MobileEventEntity` to be sent.
    ///   - completion: Closure called with `.continue` to proceed with next item,
    ///                 or `.retry` to stop the flow and schedule a retry.
    private func handleEvent(
        context: NSManagedObjectContext,
        event: MobileEventEntity,
        completion: @escaping (SignResult) -> Void
    ) {
        let dto = MobileEventData.from(entity: event)

        self.sendMobileEventRequest(event: dto) { eventResult in
            if eventResult is RetryEvent {
                mobileEventLimit(context: context, for: event) { allowed in
                completion(allowed ? .continue : .retry)
                }
                return
            }

            deleteMobileEvent(context: context, entity: event) { deleted in
                completion(deleted ? .continue : .retry)
            }
        }
    }

    /// Builds and sends a multipart mobile event request based on the provided DTO.
    /// Converts DTO into multipart parts, resolves request data, and dispatches via `RequestManager`.
    ///
    /// - Parameters:
    ///   - event: The `MobileEventData` DTO used to create multipart parts.
    ///   - completion: Closure called with the resulting `Event` (success, failure, or retry).
    func sendMobileEventRequest(
        event: MobileEventData,
        completion: @escaping (Event) -> Void
    ) {
        let parts = PartsFactory.createMobileEventParts(from: event)

        getMobileEventRequestData(eventData: event) { requestData in
            guard let requestData = requestData else {
                completion(retryEvent(#function, error: mobileRequestDataIsNil))
                return
            }

            guard let request = createMobileEventMultipartRequest(
                baseURLString: requestData.url,
                sid: requestData.sid,
                parts: parts,
                authHeader: requestData.authHeader
            ) else {
                completion(retryEvent(#function, error: failedCreateRequest))
                return
            }

            RequestManager().sendRequest(
                request: request,
                requestName: Constants.RequestName.mobileEvent,
                name: event.eventName,
                completion: completion
            )
        }
    }
}
