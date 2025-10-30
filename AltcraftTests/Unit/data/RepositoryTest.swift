//
//  RepositoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * RepositoryTests
 *
 * Positive scenarios:
 *  - test_1_getAuthData_withRToken_returnsBearerRToken: getAuthData builds a Bearer header from a non-empty rToken.
 *  - test_2_SubscribeRequestData_isValid_success: SubscribeRequestData.isValid returns true for a fully populated request.
 *  - test_3_PushEventRequestData_isValid_allowedTypes: PushEventRequestData.isValid accepts only allowed types.
 *  - test_4_decodeJSONData_validDictionary: decodeJSONData parses a valid JSON dictionary.
 *  - test_8_MobileEventRequestData_validData_success: MobileEventRequestData is properly constructed with valid entity data.
 *  - test_9_PartsFactory_createMobileEventParts_allFields: PartsFactory creates all expected parts from complete entity.
 *
 * Edge scenarios:
 *  - test_5_SubscribeRequestData_isValid_missingMandatoryFields: SubscribeRequestData.isValid returns false for missing/empty required fields.
 *  - test_6_PushEventRequestData_isValid_invalidType: PushEventRequestData.isValid rejects non-allowed type values.
 *  - test_7_decodeJSONData_rootArray_returnsNil: decodeJSONData returns nil if JSON root is an array.
 *  - test_10_MobileEventRequestData_missingRequiredFields_returnsNil: getMobileEventRequestData returns nil when required fields are missing.
 *  - test_11_PartsFactory_createMobileEventParts_partialFields: PartsFactory handles partial data correctly.
 *  - test_12_MobileEventRequestData_invalidObjectID_returnsNil: getMobileEventRequestData returns nil for invalid object ID.
 */
final class RepositoryTests: IsolatedTestCase {
    
    private func createMobileEventEntity(
        sid: String = "test-sid",
        eventName: String = "test-event",
        time: Int64 = 1_725_000_000,
        timeZone: Int32 = 180,
        altcraftClientID: String = "test-client-id",
        matchingType: String? = "test-matching",
        utmTags: Data? = nil,
        payload: Data? = nil,
        sendMessageId: String? = nil,
        matching: Data? = nil,
        subscription: Data? = nil,
        profileFields: Data? = nil
    ) -> MobileEventEntity {
        let entity = MobileEventEntity(context: viewContext)
        entity.sid = sid
        entity.eventName = eventName
        entity.time = time
        entity.timeZone = Int16(timeZone)
        entity.altcraftClientID = altcraftClientID
        entity.matchingType = matchingType
        entity.utmTags = utmTags
        entity.payload = payload
        entity.sendMessageId = sendMessageId
        entity.matching = matching
        entity.subscription = subscription
        entity.profileFields = profileFields
        
        try? viewContext.save()
        return entity
    }

    /// Make a JSON Data from a dictionary.
    private func jsonData(_ object: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    // MARK: - getAuthData

    /// test_1_getAuthData_withRToken_returnsBearerRToken
    func test_1_getAuthData_withRToken_returnsBearerRToken() {
        let token = "rTok123"
        let result = getAuthData(rToken: token)
        XCTAssertNotNil(result, "Expected non-nil auth data when rToken is provided")
        XCTAssertEqual(result?.0, "Bearer rtoken@\(token)", "Auth header must be Bearer rtoken@<rToken>")
        XCTAssertEqual(result?.1, token, "Matching mode should equal rToken")
    }

    /// test_2_SubscribeRequestData_isValid_success
    func test_2_SubscribeRequestData_isValid_success() {
        let req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: "r123",
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: 1,
            profileFields: ["p": "v"],
            customFields: ["c": "v"],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertTrue(req.isValid(), "Expected true for fully-populated, valid SubscribeRequestData")
    }

    /// test_5_SubscribeRequestData_isValid_missingMandatoryFields
    func test_5_SubscribeRequestData_isValid_missingMandatoryFields() {
        var req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when requestId is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 0,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when time is 0")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when authHeader is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when matchingMode is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "",
            deviceToken: "token-xyz",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when provider is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when deviceToken is empty")

        // Empty status
        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            time: 1_725_000_000,
            rToken: nil,
            requestId: "uuid-1",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "",
            sync: 0,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when status is empty")
    }

    /// test_3_PushEventRequestData_isValid_allowedTypes
    func test_3_PushEventRequestData_isValid_allowedTypes() {
        // Allowed type: delivery
        var req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u1",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertTrue(req.isValid(), "Expected true for allowed type 'delivery'")

        // Allowed type: open
        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: Constants.PushEvents.open,
            uid: "u2",
            authHeader: "Bearer def",
            matchingMode: "m"
        )
        XCTAssertTrue(req.isValid(), "Expected true for allowed type 'open'")
    }

    /// test_6_PushEventRequestData_isValid_invalidType
    func test_6_PushEventRequestData_isValid_invalidType() {
        var req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: "clicked",
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false for non-allowed type")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 0,
            type: Constants.PushEvents.open,
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when time is 0")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: Constants.PushEvents.open,
            uid: "",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when uid is empty")

        // Invalid because of empty authHeader
        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u4",
            authHeader: "",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when authHeader is empty")

        // Invalid because of empty matchingMode
        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u4",
            authHeader: "Bearer abc",
            matchingMode: ""
        )
        XCTAssertFalse(req.isValid(), "Expected false when matchingMode is empty")
    }

    /// test_4_decodeJSONData_validDictionary
    func test_4_decodeJSONData_validDictionary() {
        let dict = ["a": "1", "n": 10] as [String : Any]
        let data = jsonData(dict)
        let decoded = decodeAnyMap(data)
        XCTAssertEqual(decoded?["a"] as? String, "1")
        XCTAssertEqual(decoded?["n"] as? Int, 10)
    }

    /// test_7_decodeJSONData_rootArray_returnsNil
    func test_7_decodeJSONData_rootArray_returnsNil() {
        let data = try! JSONSerialization.data(withJSONObject: [1,2,3], options: [])
        let decoded = decodeAnyMap(data)
        XCTAssertNil(decoded, "Expected nil when root JSON object is an array")
    }

    /// test_8_MobileEventRequestData_validData_success
    func test_8_MobileEventRequestData_validData_success() {
        let entity = createMobileEventEntity()
        
        let requestData = MobileEventRequestData(
            url: "https://api.example.com/mobile-event",
            sid: entity.sid!,
            eventName: entity.eventName!,
            parts: [],
            authHeader: "Bearer test-auth"
        )
        
        XCTAssertEqual(requestData.sid, "test-sid")
        XCTAssertEqual(requestData.eventName, "test-event")
        XCTAssertEqual(requestData.authHeader, "Bearer test-auth")
        XCTAssertEqual(requestData.url, "https://api.example.com/mobile-event")
        XCTAssertTrue(requestData.parts.isEmpty)
    }

    /// test_9_PartsFactory_createMobileEventParts_allFields
    func test_9_PartsFactory_createMobileEventParts_allFields() {
        let utmObject = UTM(
            campaign: "test-campaign",
            content: "test-content",
            keyword: "test-keyword",
            medium: "test-medium",
            source: "test-source",
            temp: "test-temp"
        )
        
        let utmData = encodeUTM(utmObject)
        
        let payloadDict = ["key": "value"]
        let payloadData = try? JSONSerialization.data(withJSONObject: payloadDict)
        
        let matchingDict = ["match": "data"]
        let matchingData = try? JSONSerialization.data(withJSONObject: matchingDict)
        
        let subscriptionDict = ["sub": "data"]
        let subscriptionData = try? JSONSerialization.data(withJSONObject: subscriptionDict)
        
        let profileDict = ["profile": "field"]
        let profileData = try? JSONSerialization.data(withJSONObject: profileDict)
        

        let entity = createMobileEventEntity(
            time: 1_725_000,
            utmTags: utmData,
            payload: payloadData,
            sendMessageId: "test-smid",
            matching: matchingData,
            subscription: subscriptionData,
            profileFields: profileData
        )
        
        let parts = PartsFactory.createMobileEventParts(from: entity)
        
        print("=== DEBUG PARTS ===")
        parts.forEach { part in
            let dataString = String(data: part.data, encoding: .utf8) ?? "binary"
            print("Part: \(part.name), data: '\(dataString)', size: \(part.data.count) bytes")
        }
        print("Total parts: \(parts.count)")
        
        let timeZonePart = parts.first { $0.name == Constants.MobileEvents.TIME_ZONE }
        XCTAssertEqual(timeZonePart?.data, Data("180".utf8))
        
        let timePart = parts.first { $0.name == Constants.MobileEvents.TIME_MOB }
        XCTAssertEqual(timePart?.data, Data("1725000".utf8))
        
        let clientIDPart = parts.first { $0.name == Constants.MobileEvents.ALTCRAFT_CLIENT_ID }
        XCTAssertEqual(clientIDPart?.data, Data("test-client-id".utf8))
        
        let eventNamePart = parts.first { $0.name == Constants.MobileEvents.MOB_EVENT_NAME }
        XCTAssertEqual(eventNamePart?.data, Data("test-event".utf8))

        let matchingTypePart = parts.first { $0.name == Constants.MobileEvents.MATCHING_TYPE }
        XCTAssertNotNil(matchingTypePart)
        XCTAssertEqual(matchingTypePart?.data, Data("test-matching".utf8))
        
        let utmCampaignPart = parts.first { $0.name == Constants.MobileEvents.UTM_CAMPAIGN }
        XCTAssertNotNil(utmCampaignPart)
        XCTAssertEqual(utmCampaignPart?.data, Data("test-campaign".utf8))
        
        let utmContentPart = parts.first { $0.name == Constants.MobileEvents.UTM_CONTENT }
        XCTAssertNotNil(utmContentPart)
        XCTAssertEqual(utmContentPart?.data, Data("test-content".utf8))
        
        let utmKeywordPart = parts.first { $0.name == Constants.MobileEvents.UTM_KEYWORD }
        XCTAssertNotNil(utmKeywordPart)
        XCTAssertEqual(utmKeywordPart?.data, Data("test-keyword".utf8))
        
        let utmMediumPart = parts.first { $0.name == Constants.MobileEvents.UTM_MEDIUM }
        XCTAssertNotNil(utmMediumPart)
        XCTAssertEqual(utmMediumPart?.data, Data("test-medium".utf8))
        
        let utmSourcePart = parts.first { $0.name == Constants.MobileEvents.UTM_SOURCE }
        XCTAssertNotNil(utmSourcePart)
        XCTAssertEqual(utmSourcePart?.data, Data("test-source".utf8))
        
        let utmTempPart = parts.first { $0.name == Constants.MobileEvents.UTM_TEMP }
        XCTAssertNotNil(utmTempPart)
        XCTAssertEqual(utmTempPart?.data, Data("test-temp".utf8))

        let jsonParts = parts.filter { $0.mime.contains("application/json") }
        XCTAssertEqual(jsonParts.count, 5)
        
        XCTAssertEqual(parts.count, 16)
    }
    
    /// test_10_MobileEventRequestData_missingRequiredFields_returnsNil
    func test_10_MobileEventRequestData_missingRequiredFields_returnsNil() {
        let expectation = self.expectation(description: "Mobile event request completion")
        
        // Entity with missing sid
        let entity = createMobileEventEntity(sid: "")
        let objectID = entity.objectID
        
        getMobileEventRequestData(context: viewContext, objectID: objectID) { requestData in
            XCTAssertNil(requestData, "Expected nil when sid is empty")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }

    /// test_11_PartsFactory_createMobileEventParts_partialFields
    func test_11_PartsFactory_createMobileEventParts_partialFields() {
        // Entity with only required fields
        let entity = createMobileEventEntity(
            matchingType: nil,
            utmTags: nil,
            payload: nil,
            sendMessageId: nil,
            matching: nil,
            subscription: nil,
            profileFields: nil
        )
        
        let parts = PartsFactory.createMobileEventParts(from: entity)
        
        XCTAssertEqual(parts.count, 4)
        
        let matchingTypePart = parts.first { $0.name == Constants.MobileEvents.MATCHING_TYPE }
        XCTAssertNil(matchingTypePart)
        
        let payloadPart = parts.first { $0.name == Constants.MobileEvents.PAYLOAD }
        XCTAssertNil(payloadPart)
    }

    /// test_12_MobileEventRequestData_invalidObjectID_returnsNil
    func test_12_MobileEventRequestData_invalidObjectID_returnsNil() {
        let expectation = self.expectation(description: "Mobile event request completion")
        
        let entity = createMobileEventEntity()
        let invalidObjectID = entity.objectID
        
        let differentContext = newBGContext()
        
        getMobileEventRequestData(context: differentContext, objectID: invalidObjectID) { requestData in
            XCTAssertNil(requestData, "Expected nil for invalid object ID")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
}
