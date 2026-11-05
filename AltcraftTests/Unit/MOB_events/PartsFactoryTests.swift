//
//  PartsFactoryTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
 * PartsFactoryTests
 *
 * Positive scenarios:
 *  - test_1: createTargetEventParts with all required fields → includes timeZone, time, clientID, and eventName as text parts.
 *  - test_2: createTargetEventParts with optional fields → includes matchingType, sendMessageId, and payload when present.
 *  - test_3: createTargetEventParts with time values → correctly converts milliseconds to seconds and leaves seconds unchanged.
 *  - test_4: createTargetEventParts with UTM data → processes campaign, source, and medium from JSON as text parts.
 *  - test_5: createTargetEventParts with JSON data → creates application/json parts for matching, subscription, and profileFields.
 *  - test_6: epochSeconds with milliseconds input → converts to seconds by dividing by 1000.
 *  - test_7: epochSeconds with seconds input → returns value unchanged.
 *  - test_8: Time conversion boundary cases → correctly handles threshold values for milliseconds/seconds detection.
 */
final class PartsFactoryTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override class var sdkManagerContainer: NSPersistentContainer? {
        targetDatabase.persistentContainer
    }

    /// test_1: createTargetEventParts with all required fields → includes timeZone, time, clientID, and eventName as text parts
    func test_1_createTargetEventParts_createsRequiredTextParts() {
        let event = createTargetEntity(
            timeZone: 180,
            time: 1_234_567_890,
            altcraftClientID: "test_client_123",
            eventName: "test_event"
        )

        let parts = PartsFactory.createTargetEventParts(from: event)
        let timeZonePart = parts.first { $0.name == TargetConstants.TargetEvents.TIME_ZONE }
        let timePart = parts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        let clientIDPart = parts.first { $0.name == TargetConstants.TargetEvents.ALTCRAFT_CLIENT_ID }
        let eventNamePart = parts.first { $0.name == TargetConstants.TargetEvents.MOB_EVENT_NAME }
        
        XCTAssertEqual(String(data: timeZonePart?.data ?? Data(), encoding: .utf8), "180")
        XCTAssertEqual(String(data: timePart?.data ?? Data(), encoding: .utf8), "1234567890")
        XCTAssertEqual(String(data: clientIDPart?.data ?? Data(), encoding: .utf8), "test_client_123")
        XCTAssertEqual(String(data: eventNamePart?.data ?? Data(), encoding: .utf8), "test_event")
    }
    
    /// test_2: createTargetEventParts with optional fields → includes matchingType, sendMessageId, and payload when present
    func test_2_createTargetEventParts_handlesOptionalFields() {
        let event = createTargetEntity(
            matchingType: "email",
            sendMessageId: "msg_123",
            payload: #"{"key":"value"}"#.data(using: .utf8)
        )
        
        let parts = PartsFactory.createTargetEventParts(from: event)
        let matchingTypePart = parts.first { $0.name == TargetConstants.TargetEvents.MATCHING_TYPE }
        let smidPart = parts.first { $0.name == TargetConstants.TargetEvents.SMID_MOB }
        let payloadPart = parts.first { $0.name == TargetConstants.TargetEvents.PAYLOAD }
        
        XCTAssertEqual(String(data: matchingTypePart?.data ?? Data(), encoding: .utf8), "email")
        XCTAssertEqual(String(data: smidPart?.data ?? Data(), encoding: .utf8), "\"msg_123\"")
        XCTAssertEqual(String(data: payloadPart?.data ?? Data(), encoding: .utf8), #"{"key":"value"}"#)
    }
    
    /// test_3: createTargetEventParts with time values → correctly converts milliseconds to seconds and leaves seconds unchanged
    func test_3_createTargetEventParts_convertsTimeCorrectly() {
        let millisEvent = createTargetEntity(time: 1_700_000_000_000)
        let secondsEvent = createTargetEntity(time: 1_234_567_890)
        let millisParts = PartsFactory.createTargetEventParts(from: millisEvent)
        let secondsParts = PartsFactory.createTargetEventParts(from: secondsEvent)
        let millisTimePart = millisParts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        let secondsTimePart = secondsParts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        
        XCTAssertEqual(String(data: millisTimePart?.data ?? Data(), encoding: .utf8), "1700000000")
        XCTAssertEqual(String(data: secondsTimePart?.data ?? Data(), encoding: .utf8), "1234567890")
    }
    
    /// test_4: createTargetEventParts with UTM data → processes campaign, source, and medium from JSON as text parts
    func test_4_createTargetEventParts_processesUTMData() {
        let utmJSON = """
        {
            "campaign": "test_campaign",
            "source": "test_source",
            "medium": "email"
        }
        """.data(using: .utf8)
        
        let event = createTargetEntity(utmTags: utmJSON)
        let parts = PartsFactory.createTargetEventParts(from: event)
        let campaignPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_CAMPAIGN }
        let sourcePart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_SOURCE }
        let mediumPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_MEDIUM }
        
        XCTAssertEqual(String(data: campaignPart?.data ?? Data(), encoding: .utf8), "test_campaign")
        XCTAssertEqual(String(data: sourcePart?.data ?? Data(), encoding: .utf8), "test_source")
        XCTAssertEqual(String(data: mediumPart?.data ?? Data(), encoding: .utf8), "email")
    }
    
    /// test_5: createTargetEventParts with JSON data → creates application/json parts for matching, subscription, and profileFields
    func test_5_createTargetEventParts_createsJsonPartsWhenDataExists() {
        let event = createTargetEntity(
            matching: #"{"type":"email"}"#.data(using: .utf8),
            subscription: #"{"status":"active"}"#.data(using: .utf8),
            profileFields: #"{"name":"John"}"#.data(using: .utf8)
        )
        
        let parts = PartsFactory.createTargetEventParts(from: event)
        let matchingPart = parts.first { $0.name == TargetConstants.TargetEvents.MATCHING_MOB }
        let subscriptionPart = parts.first { $0.name == TargetConstants.TargetEvents.SUBSCRIPTION_MOB }
        let profileFieldsPart = parts.first { $0.name == TargetConstants.TargetEvents.PROFILE_FIELDS_MOB }
        
        XCTAssertNotNil(matchingPart)
        XCTAssertNotNil(subscriptionPart)
        XCTAssertNotNil(profileFieldsPart)
        XCTAssertEqual(matchingPart?.mime, "application/json; charset=utf-8")
        XCTAssertEqual(subscriptionPart?.mime, "application/json; charset=utf-8")
        XCTAssertEqual(profileFieldsPart?.mime, "application/json; charset=utf-8")
    }
    
    /// test_6: epochSeconds with milliseconds input → converts to seconds by dividing by 1000
    func test_6_epochSeconds_convertsMillisecondsToSeconds() {
        let milliseconds: Int64 = 1_700_000_000_000
        let result = epochSeconds(fromMillis: milliseconds)
        XCTAssertEqual(result, 1_700_000_000)
    }
    
    /// test_7: epochSeconds with seconds input → returns value unchanged
    func test_7_epochSeconds_leavesSecondsAsIs() {
        let seconds: Int64 = 1_234_567_890
        let result = epochSeconds(fromMillis: seconds)
        XCTAssertEqual(result, seconds)
    }
    
    /// test_8: Time conversion boundary cases → correctly handles threshold values for milliseconds/seconds detection
    func test_8_timeConversion_boundaryCases() {
        let thresholdEvent = createTargetEntity(time: 1_000_000_000_000)
        let belowThresholdEvent = createTargetEntity(time: 999_999_999_999)
        let aboveThresholdEvent = createTargetEntity(time: 1_000_000_000_001)
        
        let thresholdParts = PartsFactory.createTargetEventParts(from: thresholdEvent)
        let belowParts = PartsFactory.createTargetEventParts(from: belowThresholdEvent)
        let aboveParts = PartsFactory.createTargetEventParts(from: aboveThresholdEvent)
        
        let thresholdTime = thresholdParts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        let belowTime = belowParts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        let aboveTime = aboveParts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
       
        XCTAssertEqual(String(data: thresholdTime?.data ?? Data(), encoding: .utf8), "1000000000")
        XCTAssertEqual(String(data: belowTime?.data ?? Data(), encoding: .utf8), "999999999999")
        XCTAssertEqual(String(data: aboveTime?.data ?? Data(), encoding: .utf8), "1000000000")
    }
    
    private func createTargetEntity(
        timeZone: Int = 0,
        time: Int64 = 0,
        altcraftClientID: String? = "default_client",
        eventName: String? = "default_event",
        matchingType: String? = nil,
        sendMessageId: String? = nil,
        utmTags: Data? = nil,
        payload: Data? = nil,
        matching: Data? = nil,
        subscription: Data? = nil,
        profileFields: Data? = nil
    ) -> TargetEntity {
        
        let entity = TargetEntity(context: viewContext)
        entity.timeZone = Int16(timeZone)
        entity.time = time
        entity.altcraftClientID = altcraftClientID
        entity.eventName = eventName
        entity.matchingType = matchingType
        entity.sendMessageId = sendMessageId
        entity.utmTags = utmTags
        entity.payload = payload
        entity.matching = matching
        entity.subscription = subscription
        entity.profileFields = profileFields
        
        return entity
    }
}

private func epochSeconds(fromMillis ms: Int64) -> Int64 {
    if ms >= 1_000_000_000_000 {
        return ms / 1000
    } else {
        return ms
    }
}
