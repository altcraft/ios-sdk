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

    /// Manager for accessing stored user-related variables.
    let userDefault = StoredVariablesManager.shared
    
    private let pushEventQueue = DispatchQueue(label: Constants.Queues.pushEventQueue)
     
     /// Result type to control next step in subscription processing.
     private enum RequestResult {
         case completed
         case retry
     }
     
    /// Retries sending the push event if the initial attempt fails.
    ///
    /// - Parameters:
    ///   - context: The Core Data context used for background operations.
    ///   - event: The push event entity to retry.
    private func retry(event: NSManagedObjectID) {
        requestRetry(request: Constants.FunctionsCode.PE, event: event)
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
         
         addPushEventEntity(uid: uid, type: type) { objectID in
             guard let entity = objectID else { return }
             pushEventRetryCount = 0
             self.sendPushEvent(objectID: entity)
         }
     }
     
     /// Sends a previously saved push event to the remote server.
     ///
     /// - Parameters:
     ///   - context: The Core Data context used for the operation.
     ///   - entity: The push event entity to be sent.
     func sendPushEvent(
         context: NSManagedObjectContext? = nil,
         objectID: NSManagedObjectID,
         shouldRetry: Bool = true,
         completion: (() -> Void)? = nil
     ) {
         let ctx = context ?? getContext()
         handlePushEvent(context: ctx, objectId: objectID) { completed in
             if completed == .retry && shouldRetry { self.retry(event: objectID) }
             completion?()
         }
     }
     
     /// Handles a single subscription: decides whether to continue or retry.
     ///
     /// - Parameters:
     ///   - context: The managed object context for Core Data operations.
     ///   - subscription: Subscription to process.
     ///   - completion: Called with `.continue` to proceed or `.retry` to abort with retry.
     private func handlePushEvent(
         context: NSManagedObjectContext,
         objectId: NSManagedObjectID,
         completion: @escaping (RequestResult) -> Void
     ) {
         self.sendPushEventRequest(context: context, objectID: objectId) { result in
             if result is RetryEvent {
                 retryLimit(context: context, for: objectId) { limit in completion(limit ? .completed : .retry) }
                 return
             }
             deleteEntity(context: context, objectID: objectId) { deleted in completion(deleted ? .completed : .retry) }
         }
     }
     
     /// Executes the subscription flow for a single entity, including request preparation and network submission.
     ///
     /// - Parameters:
     ///   - entity: A `SubscribeEntity` representing stored subscription details.
     ///   - completion: Closure called with the resulting `Event` (success, failure, or retry event).
     func sendPushEventRequest(
         context: NSManagedObjectContext,
         objectID: NSManagedObjectID,
         completion: @escaping (Event) -> Void
     ) {
         getPushEventRequestData(context: context, objectID: objectID) { data in
             guard let data = data else {
                 completion(retryEvent(#function, error: pushEventRequestDataIsNil))
                 return
             }
             
             guard let request = pushEventRequest(data: data) else {
                 completion(retryEvent(#function, error: failedCreateRequest))
                 return
             }
             
             RequestManager.shared.sendRequest(
                request: request, requestName: Constants.RequestName.pushEvent, uid: data.uid, type: data.type, completion: completion
             )
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
     func sendAllPushEvents(completion: @escaping () -> Void = {}) {
         let context = getContext()
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
                         self.sendPushEvent(context: context, objectID: event, shouldRetry: false) {
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
