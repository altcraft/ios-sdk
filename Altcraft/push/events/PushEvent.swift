//
//  PushEvent.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// A singleton class responsible for managing push notification events.
///
/// `PushEvent` handles the creation, storage, and network transmission
/// of push notification delivery events. Events are saved in Core Data,
/// retried on failure, and deleted upon success.
 class PushEvent: NSObject {
    
    /// Shared singleton instance of `PushEvent`.
    static let shared = PushEvent()
    
    /// The function code used for analytics or logging purposes.
    let funcName = Constants.FunctionsCode.PE

    /// Manager for accessing stored user-related variables.
    let userDefault = StoredVariablesManager.shared
    
    /// Provides access to background execution features.
    let backgroundTask = AccessToBackground.shared
    
    /// Provides access to request and response functions
    let requestManager = RequestManager.shared
     
     private var isSending = false
     
     private let pushEventQueue = DispatchQueue(label: Constants.Queues.pushEventQueue)

    /// Retries sending the push event if the initial attempt fails.
    ///
    /// - Parameters:
    ///   - context: The Core Data context used for background operations.
    ///   - event: The push event entity to retry.
    private func retry(context: NSManagedObjectContext, event: PushEventEntity) {
        requestRetry(request: funcName, context: context, event: event)
    }

    /// Creates and stores a new push event based on received payload data.
    ///
    /// - Parameters:
    ///   - userInfo: The dictionary received in the push notification payload.
    ///   - type: A string representing the event type (e.g., "delivered", "opened").
    func createPushEvent(userInfo: [String: Any], type: String) {
        guard let uid = userInfo[Constants.UserInfoKeys.uid] as? String else {
            errorEvent(#function, error: uidIsNil)
            return
        }
        getContext { context in
            addPushEventEntity(context: context, uid: uid, type: type) { entity in
                guard let entity = entity else { return }
                self.sendPushEvent(context: context, entity: entity)
            }
        }
    }
     
    /// Sends a previously saved push event to the remote server.
    ///
    /// - Parameters:
    ///   - context: The Core Data context used for the operation.
    ///   - entity: The push event entity to be sent.
     func sendPushEvent(
        context: NSManagedObjectContext,
        entity: PushEventEntity,
        shouldRetry: Bool = true,
        completion: (() -> Void)? = nil
     ) {
         getPushEventRequestData(entity: entity) { data in
             guard let data = data else {
                 retryEvent(#function, error: pushEventRequestDataIsNil)
                 if shouldRetry {self.retry(context: context, event: entity)} else {
                     completion?()
                 }
                 return
             }
             
             guard let request = pushEventRequest(data: data) else {
                 retryEvent(#function, error: failedCreateRequest)
                 if shouldRetry {self.retry(context: context, event: entity)} else {
                     completion?()
                 }
                 return
             }
             
             self.requestManager.sendRequest(
                request: request,
                requestName: Constants.RequestName.pushEvent,
                uid: entity.uid,
                type: entity.type
             ) { event in
                 if shouldRetry {
                     self.handlePushEventResponse(context: context, entity: entity, event: event)
                 } else {
                     if !(event is RetryEvent) {deletePushEvent(context: context, entity: entity) { _ in
                         completion?()}
                     } else {
                         completion?()
                     }
                 }
             }
         }
     }
     
     /// Handles the result of a push event request.
     ///
     /// This method processes the result of a network request related to a push event.
     /// Based on the result, it may delete the associated `PushEventEntity`,
     /// emit events, or trigger retries.
     ///
     /// - Parameters:
     ///   - context: The `NSManagedObjectContext` used for Core Data operations.
     ///   - entity: The `PushEventEntity` representing the push event.
     ///   - event: The `Event` returned by the network request.
     private func handlePushEventResponse(
        context: NSManagedObjectContext,
        entity: PushEventEntity,
        event: Event
     ) {
         if !(event is RetryEvent) {
             deletePushEvent(context: context, entity: entity) { result in
                 if !result {self.retry(context: context, event: entity)}}
         } else {
             pushEventLimit(context: context, for: entity) { limit in
                 if !limit {self.retry(context: context, event: entity)}}
         }
     }

    /// Sends all pending `PushEventEntity` events stored in Core Data with completion callback.
    ///
    /// This version uses DispatchGroup to track completion of all send attempts.
    /// If `completion` is provided, it will be called when all sends are finished.
    ///
    /// - Parameters:
    ///   - context: The Core Data context to use.
    ///   - completion: Called when all events are processed (optional, default is empty closure).
     func sendAllPushEvents(
         context: NSManagedObjectContext,
         completion: @escaping () -> Void = {}
     ) {
         pushEventQueue.async {
             let group = DispatchGroup()

             clearOldPushEvents(context: context) { 
                 getAllPushEvents(context: context) { events in
                     guard !events.isEmpty else {
                         DispatchQueue.main.async { completion() }
                         return
                     }

                     for event in events {
                         group.enter()
                         self.sendPushEvent(context: context, entity: event, shouldRetry: false) {
                             group.leave()
                         }
                     }

                     group.notify(queue: self.pushEventQueue) {
                         DispatchQueue.main.async {
                             completion()
                         }
                     }
                 }
             }
         }
     }
}
