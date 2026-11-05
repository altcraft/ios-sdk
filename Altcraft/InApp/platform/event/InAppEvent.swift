//
//  InAppEvent.swift
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

/// A singleton actor responsible for managing in-app message events.
///
/// `InAppEventProcess` creates, stores, sends, retries, and deletes in-app event records.
/// Events are first persisted into Core Data and then sent to the server.
/// If sending fails with a retryable result, the stored entity is retried later.
@available(iOSApplicationExtension, unavailable)
internal actor InAppEventProcess {

    /// Shared singleton instance of `InAppEventProcess`.
    static let shared = InAppEventProcess()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    /// - Returns: Function name decorated with the in-app event scope.
    private func getFunc(_ name: String) -> String {
        "\(name) :: InAppEventProcess"
    }

    /// Creates and stores a new in-app event, then immediately attempts to send it.
    ///
    /// The method resolves the current ACID from internal authentication data,
    /// validates `smid` and `acid`, serializes optional payload data, creates a
    /// Core Data entity, resets the retry counter, and sends the event.
    /// If `smid` is `nil` or empty, or `acid` is empty, the method logs an error
    /// and returns early without creating an event.
    ///
    /// - Parameters:
    ///   - smid: Send Message ID of the in-app message. If `nil` or empty, the event is not created.
    ///   - type: In-app event type.
    ///   - data: Optional payload for event types that support additional data, such as `click` and `error`.
    func createInAppEvent(
        smid: String?,
        type: InAppModel.InAppEventType,
        data: RequestModel.InAppEventData? = nil
    ) async {
        do {
            let env = InAppEnvironment.fresh()
            let internalAuth = try await env.internalAuth()
            let acid = internalAuth.currentAcid

            guard let smid, !smid.isEmpty else {
                InAppLog.error(#function, error: InAppModuleEvents.smidIsNil)
                return
            }

            guard !acid.isEmpty else {
                InAppLog.error(#function, error: InAppModuleEvents.acidIsNil)
                return
            }

            guard let event = await InAppEventDAO.addInAppEventEntity(
                smid: smid,
                acid: acid,
                type: type.rawValue,
                data: encodeInAppEventData(data)
            ) else {
                return
            }

            RetryCounters.shared.reset(InAppConstants.RetryKey.inAppEvent)

            await sendInAppEvent(
                context: inAppDatabase.getContext(),
                event: event
            )
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Sends a stored in-app event to the remote server.
    ///
    /// The method builds request data from the stored Core Data entity and sends it.
    /// On a retryable result, the entity remains in storage and a retry is scheduled.
    /// On a non-retry result, delivery events update local report status and the entity
    /// is deleted from Core Data.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for loading and deleting the entity.
    ///   - event: `NSManagedObjectID` of the stored `InAppEventEntity`.
    ///   - shouldRetry: Whether retry scheduling should be applied on retryable failure.
    func sendInAppEvent(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
        shouldRetry: Bool = true
    ) async {
        let response = await request(context: context, event: event)

        let isRetry: Bool

        switch response {
        case is RetryEvent:
            isRetry = await !retryLimit(context: context, objectID: event)

        default:
            if let eventData = await getInAppEventRequestData(
                context: context,
                objectID: event
            ),
               eventData.type == InAppConstants.InAppEvents.delivery {
                await InAppDAO.setInAppReportStatus(smid: eventData.smid)
            }

            isRetry = await !deleteEntity(context: context, objectID: event)
        }

        if isRetry && shouldRetry { inAppEventRetry(objectID: event) }
    }

    /// Prepares and sends an in-app event request.
    ///
    /// The stored event data is loaded from Core Data using the provided object ID,
    /// converted into `RequestModel.InAppEventRequestData`, transformed into a URL request,
    /// and sent through `RequestManager`.
    ///
    /// - Parameters:
    ///   - context: Managed object context used to resolve the stored entity.
    ///   - event: `NSManagedObjectID` of the stored `InAppEventEntity`.
    /// - Returns: Resulting SDK `Event` describing success, retry, or failure.
    func request(
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Event {
        let function = getFunc(#function)

        guard let data = await getInAppEventRequestData(
            context: context,
            objectID: event
        ) else {
            return InAppLog.retry(
                function,
                error: InAppModuleEvents.inAppEventRequestDataIsNil
            )
        }

        guard let request = await inAppEventRequest(data: data) else {
            return InAppLog.retry(
                function,
                error: CoreEvents.failedCreateRequest
            )
        }

        return await RequestManager.shared
            .sendRequest(request: request, requestData: data)
            .event
    }

    /// Sends all pending in-app events stored in Core Data.
    ///
    /// Events are processed in batches of 10:
    /// - outdated records are cleared first;
    /// - event object IDs are fetched ordered by creation time;
    /// - every batch is sent concurrently using separate Core Data contexts;
    /// - retry scheduling is disabled for batch processing because the caller controls retry flow.
    func sendAllInAppEvents() async {
        let context = inAppDatabase.getContext()
        await InAppEventDAO.clearOldInAppEvents(context: context)

        let events = await InAppEventDAO.getAllInAppEvents(context: context)

        for start in stride(from: 0, to: events.count, by: 10) {
            await withTaskGroup(of: Void.self) { group in
                for event in events[start..<min(start + 10, events.count)] {
                    group.addTask {
                        await self.sendInAppEvent(
                            context: inAppDatabase.getContext(),
                            event: event,
                            shouldRetry: false
                        )
                    }
                }
            }
        }
    }

    /// Sends SDK-side in-app error event.
    ///
    /// The method wraps an internal SDK error into an in-app error event payload
    /// and sends it with code `500`.
    ///
    /// - Parameters:
    ///   - smid: Send Message ID associated with the in-app message.
    ///   - error: Error that occurred during in-app processing.
    func sendErrorInAppEvent(
        smid: String?,
        error: String
    ) async {
        await createInAppEvent(
            smid: smid,
            type: .error,
            data: RequestModel.InAppEventData(
                code: 500, message: error
            )
        )
    }
}
