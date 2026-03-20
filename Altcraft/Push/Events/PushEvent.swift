//
//  PushEvent.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// A singleton actor responsible for managing push notification events.
///
/// `PushEvent` handles the creation, storage, and network transmission
/// of push notification events (e.g. delivery, open). Events are saved in Core Data,
/// retried on failure, and deleted upon success.
internal actor PushEvent {
    
    /// Shared singleton instance of `PushEvent`.
    static let shared = PushEvent()
    
    /// Manager for accessing stored user-related variables.
    let userDefault = StoredVariablesManager.shared
    
    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: PushEvent"
    }
    
    /// Creates and stores a new push event.
    ///
    /// - Parameters:
    ///   - uid: The unique identifier of the push notification event.
    ///   - type: A string representing the event type (e.g. `"delivered"`, `"opened"`).
    func createPushEvent(uid: String?, type: String) async {
        guard let uid else {
            errorEvent(#function, error: uidIsNil); return
        }
        
        guard let event = await addPushEventEntity(uid: uid, type: type) else {
            return
        }
        
        RetryCounters.shared.reset(RetryKey.pushEvent)
        
        await sendPushEvent(context: CoreDataManager.shared.getContext(), event: event)
    }
    
    /// Sends a previously saved push event to the remote server.
    ///
    /// - Parameters:
    ///   - context: The Core Data context used for the operation.
    ///   - event: The `NSManagedObjectID` of the push event to be sent.
    ///   - shouldRetry: Whether retry handling should be applied on failure.
    func sendPushEvent(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        shouldRetry: Bool = true
    ) async {
        let response = await request(context: context, event: event)
        
        let isRetry = switch response {
        case is RetryEvent:
             await !retryLimit(context: context, objectID: event)
        default:
             await !deleteEntity(context: context, objectID: event)
        }
        
        if isRetry && shouldRetry { pushEventRetry(objectID: event) }
    }
        
    /// Prepares and sends a push event request.
    ///
    /// The stored event data is loaded from Core Data using the provided context,
    /// converted into request data, and then sent through `RequestManager`.
    ///
    /// - Parameters:
    ///   - context: The managed object context used to fetch the stored event data.
    ///   - event: The `NSManagedObjectID` of the stored push event entity.
    /// - Returns: The resulting `Event` describing success, retry, or failure.
    func request(
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Event {
        let function = getFunc(#function)
        guard let data = await getPushEventRequestData(
            context: context, objectID: event
        )else {
            return retryEvent(function, error: pushEventRequestDataIsNil)
        }
        
        guard let request = pushEventRequest(data: data) else {
            return retryEvent(function, error: failedCreateRequest)
        }
        
        let requestName = Constants.RequestName.pushEvent
        
        return await RequestManager.shared.sendRequest(
            request: request, requestName: requestName, uid: data.uid, type: data.type
        )
    }
    
    /// Sends all pending `PushEventEntity` events stored in Core Data.
    ///
    /// Events are processed in batches of 10:
    /// - outdated records are cleared;
    /// - event IDs are fetched;
    /// - each batch is sent in parallel using a task group;
    /// - the next batch starts only after the current one finishes.
    ///
    /// Each task uses its own background `NSManagedObjectContext` to avoid
    /// sharing a single Core Data context across concurrent operations.
    func sendAllPushEvents() async {
        let context = CoreDataManager.shared.getContext()
        await clearOldPushEvents(context: context)
        let events = await getAllPushEvents(context: context)
        
        for start in stride(from: 0, to: events.count, by: 10) {
            
            await withTaskGroup(of: Void.self) { group in
                for event in events[
                    start..<min(start + 10, events.count)
                ] {
                    group.addTask {
                        _ = await self.sendPushEvent(
                            context: CoreDataManager.shared.getContext(), event: event, shouldRetry: false
                        )
                    }
                }
            }
        }
    }
}


// MARK: - Unit Test Hooks

/// Extension exposing internal push-event processing hooks for unit tests.
extension PushEvent {

    /// Test hook for internal request flow of a single push event.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - event: `NSManagedObjectID` of the `PushEventEntity`.
    /// - Returns: Resulting `Event`.
    internal func test_push_event_request(
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Event {
        await request(context: context, event: event)
    }

    /// Test hook for sending a single push event.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - event: `NSManagedObjectID` of the `PushEventEntity`.
    ///   - shouldRetry: Whether retry handling should be applied on failure.
    internal func test_push_event_send(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        shouldRetry: Bool = true
    ) async {
        await sendPushEvent(
            context: context,
            event: event,
            shouldRetry: shouldRetry
        )
    }

    /// Test hook for creating a push event.
    ///
    /// - Parameters:
    ///   - uid: Push event identifier.
    ///   - type: Push event type.
    internal func test_push_event_create(
        uid: String?,
        type: String
    ) async {
        await createPushEvent(uid: uid, type: type)
    }

    /// Test hook for sending all queued push events.
    internal func test_push_event_send_all() async {
        await sendAllPushEvents()
    }
}
