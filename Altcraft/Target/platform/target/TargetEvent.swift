//
//  TargetEvent.swift
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

internal actor TargetEventProcess {

    static let shared = TargetEventProcess()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: TargetEventProcess"
    }

    /// Sends a mobile event to the server.
    ///
    /// Persists event metadata in Core Data and triggers processing.
    ///
    /// Waits for SDK initialization to complete before reading the user tag
    /// (Android parity, `submitSdkCommand` with `initAwait = true`), so an
    /// event submitted before `initialization` is processed once the
    /// configuration is installed instead of being dropped.
    ///
    /// - Parameters:
    ///   - sid: The string ID of the pixel.
    ///   - eventName: Event name.
    ///   - sendMessageId: Send Message ID (SMID).
    ///   - payloadData: Encoded event payload.
    ///   - matchingData: Encoded matching data.
    ///   - profileFieldsData: Encoded profile fields.
    ///   - subscriptionData: Encoded subscription data.
    ///   - altcraftClientID: Altcraft client identifier.
    ///   - matchingType: Type of matching (e.g. "push_sub", "email", etc.).
    ///   - utmTagsData: Encoded UTM tags.
    func sendTargetEvent(
        sid: String,
        eventName: String,
        payloadData: Data? = nil,
        matchingData: Data? = nil,
        sendMessageId: String? = nil,
        profileFieldsData: Data? = nil,
        subscriptionData: Data? = nil,
        altcraftClientID: String = "",
        matchingType: String? = nil,
        utmTagsData: Data? = nil
    ) async {
        guard SerialCommandQueue.isCurrent() else { return }
        let function = getFunc(#function)
        let initGate = await InitBarrier.shared.current()

        await withInitReady(function: function, gate: initGate) {
            let env = TargetEnvironment.fresh()

            do {
                try env.checkCoreDataError()
                let userTag = try await env.userTag()
                let timeZone = DeviceInfo.getTimeZone()

                switch await TargetDAO.addTargetEntity(
                    sid: sid,
                    userTag: userTag,
                    timeZone: timeZone,
                    eventName: eventName,
                    payloadData: payloadData,
                    matchingData: matchingData,
                    sendMessageId: sendMessageId,
                    matchingType: matchingType,
                    utmTagsData: utmTagsData,
                    altcraftClientID: altcraftClientID,
                    profileFieldsData: profileFieldsData,
                    subscriptionData: subscriptionData
                ) {
                case .success:
                    guard SerialCommandQueue.isCurrent() else { return }
                    RetryCounters.shared.reset(
                        TargetConstants.RetryKey.targetEvent
                    )
                    await TargetEventWorker.shared.processPending()

                case .failure(let error):
                    TargetLog.error(function, error: error)
                }
            } catch {
                TargetLog.error(function, error: error)
            }
        }
    }

    /// Enqueues mobile event processing into the serial command queue.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func enqueueStart(enableRetry: Bool = true) async {
        guard SerialCommandQueue.isCurrent() else { return }
        let function = getFunc(#function)
                
         TargetEventQueues.startQueue.submit {

            do {
                await NetworkMonitor.shared.waitConnected()
                guard SerialCommandQueue.isCurrent() else { return }

                let env = TargetEnvironment.fresh()
                let userTag = try await env.userTag()
                let result = try await self.processEvents(
                    userTag: userTag
                )

                if SerialCommandQueue.isCurrent() && !result && enableRetry {
                    mobileEventRetry()
                }
            } catch {
                TargetLog.retry(function, error: error)
                if SerialCommandQueue.isCurrent() && enableRetry {mobileEventRetry()}
            }
        }
    }

    /// Processes all stored subscriptions for the given user tag.
    ///
    /// Performs cleanup of outdated entities, fetches all queued subscriptions for `userTag`,
    /// and processes them sequentially. Returns as soon as a retry condition is met.
    ///
    /// - Parameter userTag: Tag used to fetch subscription entities.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    /// - Throws: Rethrows fetch errors so the caller can schedule a retry;
    ///   a failed read is not treated as an empty queue.
    fileprivate func processEvents(userTag: String) async throws -> Bool {
        let context = targetDatabase.getContext()

        await TargetDAO.clearOldTargets(context: context)

        let events = try await TargetDAO.getAllTargetsByTag(
            context: context,
            userTag: userTag
        )

        for event in events {
            if await isRetry(context: context, event: event){
                return false
            }
        }

        return true
    }

    /// Processes a single mobile event and determines whether a retry is required.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - event: `NSManagedObjectID` of the `TargetEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Bool {
        let response = await request(context: context, event: event)

        switch response {
        case is RetryEvent:
            return !(await retryLimit(context: context, objectID: event))
        default:
            return !(await deleteEntity(context: context, objectID: event))
        }
    }

    /// Builds and sends a multipart mobile event request based on the provided objectID.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to read event fields for the request.
    ///   - event: `NSManagedObjectID` of `TargetEntity` used to create the request.
    /// - Returns: Resulting `Event` (success, failure, or retry).
    fileprivate func request (
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Event {
        let function = getFunc(#function)
        guard let requestData = await getTargetEventRequestData(
            context: context,
            objectID: event
        ) else {
            return TargetLog.retry(function, error: TargetModuleEvents.mobileRequestDataIsNil)
        }

        guard let request = await mobileEventRequest(data: requestData) else {
            return TargetLog.retry(function, error: CoreEvents.failedCreateRequest)
        }

        return await RequestManager.shared.sendRequest(request: request, requestData: requestData)
            .event
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing fileprivate mobile-event processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension TargetEventProcess {

    /// Test hook for internal request flow of a single mobile event.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - objectID: `NSManagedObjectID` of the `TargetEntity`.
    /// - Returns: Resulting `Event`.
    internal func test_mobile_event_request(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async -> Event {
        await request(context: context, event: objectID)
    }

    /// Test hook for processing a single mobile event.
    ///
    /// - Parameters:
    ///   - context: Core Data context used for persistence operations.
    ///   - event: `NSManagedObjectID` of the `TargetEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    internal func test_mobile_event_isRetry(
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Bool {
        await isRetry(context: context, event: event)
    }

    /// Test hook for processing queued mobile events by user tag.
    ///
    /// - Parameter userTag: User tag used to fetch queued mobile events.
    /// - Returns: `true` if processing completes without retry stop, otherwise `false`.
    /// - Throws: Rethrows fetch errors from the underlying queue read.
    internal func test_mobile_event_processEvents(
        userTag: String
    ) async throws -> Bool {
        try await processEvents(userTag: userTag)
    }
}
