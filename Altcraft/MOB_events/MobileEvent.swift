//
//  MobileEvent.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

internal actor MobileEvent {

    static let shared = MobileEvent()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: MobileEvent"
    }

    /// Sends a mobile event to the server.
    ///
    /// Persists event metadata in Core Data and triggers processing.
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
    func sendMobileEvent(
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
        let function = getFunc(#function)
        let env = Environment.create()
        
        do {
            try env.checkCoreDataError()
            let userTag = try await env.userTag()
            let timeZone = DeviceInfo.getTimeZone()
            
            switch await addMobileEventEntity(
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
                RetryCounters.shared.reset(
                    RetryKey.mobileEvent
                )
                await self.enqueueStart()
                
            case .failure(let error):
                errorEvent(function, error: error)
            }
        } catch {
            errorEvent(function, error: error)
        }
    }

    /// Enqueues mobile event processing into the serial command queue.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func enqueueStart(enableRetry: Bool = true) async {
        let function = getFunc(#function)
         MobileEventQueues.startQueue.submit {
            
            do {
                await NetworkMonitor.shared.waitConnected()

                let env = Environment.create()
                let userTag = try await env.userTag()
                let result = await self.processEvents(
                    userTag: userTag
                )
                
                if !result && enableRetry {
                    mobileEventRetry()
                }
            } catch {
                retryEvent(function, error: error)
                if enableRetry {mobileEventRetry()}
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
    fileprivate func processEvents(userTag: String) async -> Bool {
        let context = CoreDataManager.shared.getContext()
        
        await clearOldMobileEvents(context: context)
        
        let events = await getAllMobileEventsByTag(
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
    ///   - event: `NSManagedObjectID` of the `MobileEventEntity`.
    /// - Returns: `true` if processing should stop and retry later, otherwise `false`.
    fileprivate func isRetry(
        context: NSManagedObjectContext,
        event: NSManagedObjectID,
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
    ///   - event: `NSManagedObjectID` of `MobileEventEntity` used to create the request.
    /// - Returns: Resulting `Event` (success, failure, or retry).
    fileprivate func request (
        context: NSManagedObjectContext,
        event: NSManagedObjectID
    ) async -> Event {
        let function = getFunc(#function)
        guard let requestData = await getMobileEventRequestData(
            context: context,
            objectID: event
        ) else {
            return retryEvent(function, error: mobileRequestDataIsNil)
        }

        guard let request = createMobileEventRequest(data: requestData) else {
            return retryEvent(function, error: failedCreateRequest)
        }

        return await RequestManager.shared.sendRequest(
            request: request, requestName: Constants.RequestName.mobileEvent, name: requestData.eventName
        )
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing fileprivate mobile-event processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension MobileEvent {
    
    /// Test hook for internal request flow of a single mobile event.
    ///
    /// - Parameters:
    ///   - context: Core Data context used to resolve the entity.
    ///   - objectID: `NSManagedObjectID` of the `MobileEventEntity`.
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
    ///   - event: `NSManagedObjectID` of the `MobileEventEntity`.
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
    internal func test_mobile_event_processEvents(
        userTag: String
    ) async -> Bool {
        await processEvents(userTag: userTag)
    }
}
