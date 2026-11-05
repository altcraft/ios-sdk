//
//  PushEvent.swift
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

/// A singleton actor responsible for managing push notification events.
///
/// `PushEventProcess` handles the creation, storage, and network transmission
/// of push notification events (e.g. delivery, open). Events are saved in Core Data,
/// retried on failure, and deleted upon success.
internal actor PushEventProcess {

    /// Shared singleton instance of `PushEventProcess`.
    static let shared = PushEventProcess()

    /// Manager for accessing stored user-related variables.
    let userDefault = PushStoredVariables.shared

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: PushEventProcess"
    }

    /// Creates and stores a new push event.
    ///
    /// If `uid` is `nil`, the method logs an error and returns early without creating an event.
    ///
    /// - Parameters:
    ///   - uid: The unique identifier of the push notification event. If `nil`, the event is not created.
    ///   - type: A string representing the event type (e.g. `"delivered"`, `"opened"`).
    func createPushEvent(uid: String?, type: String) async {
        guard let uid else {
            PushLog.error(#function, error: PushModuleEvents.uidIsNil); return
        }

        guard let event = await PushEventDAO.addPushEventEntity(uid: uid, type: type) else {
            return
        }

        RetryCounters.shared.reset(PushConstants.RetryKey.pushEvent)

        await sendPushEvent(context: pushDatabase.getContext(), event: event)
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

        // The entity is gone: drop any pending retry registered for it so
        // the retry registry does not accumulate per-entity keys.
        if !isRetry {
            RetryManager.shared.cancel(key: pushEventRetryKey(event))
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
        ) else {
            return PushLog.retry(function, error: PushModuleEvents.pushEventRequestDataIsNil)
        }

        guard let request = await pushEventRequest(data: data) else {
            return PushLog.retry(function, error: CoreEvents.failedCreateRequest)
        }

        return await RequestManager.shared.sendRequest(request: request, requestData: data).event
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
        let context = pushDatabase.getContext()
        await PushEventDAO.clearOldPushEvents(context: context)
        let events = await PushEventDAO.getAllPushEvents(context: context)

        for start in stride(from: 0, to: events.count, by: 10) {

            await withTaskGroup(of: Void.self) { group in
                for event in events[
                    start..<min(start + 10, events.count)
                ] {
                    group.addTask {
                        _ = await self.sendPushEvent(
                            context: pushDatabase.getContext(), event: event, shouldRetry: false
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing internal push-event processing hooks for unit tests.
extension PushEventProcess {

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
