//
//  RepositoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * RepositoryTests
 *
 * Positive scenarios:
 *  - test_1: Get auth data with R token returns bearer R token.
 *  - test_2: Subscribe request data is valid success.
 *  - test_3: Push event request data is valid allowed types.
 *  - test_4: Decode JSON data valid dictionary.
 *  - test_8: Mobile event request data valid data success.
 *  - test_9: Parts factory create mobile event parts all fields.
 *
 * Edge scenarios:
 *  - test_5: Subscribe request data is valid missing mandatory fields.
 *  - test_6: Push event request data is valid invalid type.
 *  - test_7: Decode JSON data root array returns nil.
 *  - test_10: Mobile event request data missing required fields returns nil.
 *  - test_11: Parts factory create mobile event parts partial fields.
 *  - test_12: Mobile event request data invalid object ID returns nil.
 */
final class RepositoryTests: IsolatedTestCase {
    
    private func createMobileEventEntity(
        requestId: String? = "req-mob-1",
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
        entity.requestId = requestId
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

    private func jsonData(_ object: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// test_1: Get auth data with R token returns bearer R token
    func test_1_getAuthData_withRToken_returnsBearerRToken() {
        let token = "rTok123"
        let result = getAuthData(rToken: token)
        XCTAssertNotNil(result, "Expected non-nil auth data when rToken is provided")
        XCTAssertEqual(result?.0, "Bearer rtoken@\(token)", "Auth header must be Bearer rtoken@<rToken>")
        XCTAssertEqual(result?.1, token, "Matching mode should equal rToken")
    }

    /// test_2: Subscribe request data is valid success
    func test_2_SubscribeRequestData_isValid_success() {
        let req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: "r123",
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: true,
            profileFields: ["p": "v"],
            customFields: ["c": "v"],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertTrue(req.isValid(), "Expected true for fully-populated, valid SubscribeRequestData")
    }

    /// test_5: Subscribe request data is valid missing mandatory fields
    func test_5_SubscribeRequestData_isValid_missingMandatoryFields() {
        var req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when requestId is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 0,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when time is 0")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when authHeader is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when matchingMode is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when provider is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when deviceToken is empty")

        req = SubscribeRequestData(
            url: "https://api.example.com/subscribe",
            requestId: "uuid-1",
            time: 1_725_000_000,
            rToken: nil,
            authHeader: "Bearer abc",
            matchingMode: "abc",
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(req.isValid(), "Expected false when status is empty")
    }

    /// test_3: Push event request data is valid allowed types
    func test_3_PushEventRequestData_isValid_allowedTypes() {
        var req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-1",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u1",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertTrue(req.isValid(), "Expected true for allowed type 'delivery'")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-2",
            time: 1_725_000_000,
            type: Constants.PushEvents.open,
            uid: "u2",
            authHeader: "Bearer def",
            matchingMode: "m"
        )
        XCTAssertTrue(req.isValid(), "Expected true for allowed type 'open'")
    }

    /// test_6: Push event request data is valid invalid type
    func test_6_PushEventRequestData_isValid_invalidType() {
        var req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-3",
            time: 1_725_000_000,
            type: "clicked",
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false for non-allowed type")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-4",
            time: 0,
            type: Constants.PushEvents.open,
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when time is 0")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-5",
            time: 1_725_000_000,
            type: Constants.PushEvents.open,
            uid: "",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when uid is empty")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-6",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u4",
            authHeader: "",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when authHeader is empty")

        req = PushEventRequestData(
            url: "https://api.example.com/push",
            requestId: "req-7",
            time: 1_725_000_000,
            type: Constants.PushEvents.delivery,
            uid: "u4",
            authHeader: "Bearer abc",
            matchingMode: ""
        )
        XCTAssertFalse(req.isValid(), "Expected false when matchingMode is empty")
    }

    /// test_4: Decode JSON data valid dictionary
    func test_4_decodeJSONData_validDictionary() {
        let dict = ["a": "1", "n": 10] as [String : Any]
        let data = jsonData(dict)
        let decoded = decodeAnyMap(data)
        XCTAssertEqual(decoded?["a"] as? String, "1")
        XCTAssertEqual(decoded?["n"] as? Int, 10)
    }

    /// test_7: Decode JSON data root array returns nil
    func test_7_decodeJSONData_rootArray_returnsNil() {
        let data = try! JSONSerialization.data(withJSONObject: [1,2,3], options: [])
        let decoded = decodeAnyMap(data)
        XCTAssertNil(decoded, "Expected nil when root JSON object is an array")
    }

    /// test_8: Mobile event request data valid data success
    func test_8_MobileEventRequestData_validData_success() {
        let entity = createMobileEventEntity()
        
        let requestData = MobileEventRequestData(
            url: "https://api.example.com/mobile-event",
            requestId: "RID-M-1",
            sid: entity.sid!,
            eventName: entity.eventName!,
            parts: [],
            authHeader: "Bearer test-auth"
        )
        
        XCTAssertEqual(requestData.sid, "test-sid")
        XCTAssertEqual(requestData.eventName, "test-event")
        XCTAssertEqual(requestData.authHeader, "Bearer test-auth")
        XCTAssertEqual(requestData.url, "https://api.example.com/mobile-event")
        XCTAssertEqual(requestData.requestId, "RID-M-1")
        XCTAssertTrue(requestData.parts.isEmpty)
    }

    /// test_9: Parts factory create mobile event parts all fields
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
    
    /// test_10: Mobile event request data missing required fields returns nil
    func test_10_MobileEventRequestData_missingRequiredFields_returnsNil() {
        let exp = self.expectation(description: "Mobile event request completion")
        
        let entity = createMobileEventEntity(sid: "")
        let objectID = entity.objectID
        
        getMobileEventRequestData(context: viewContext, objectID: objectID) { requestData in
            XCTAssertNil(requestData, "Expected nil when sid is empty")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }

    /// test_11: Parts factory create mobile event parts partial fields
    func test_11_PartsFactory_createMobileEventParts_partialFields() {
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

    /// test_12: Mobile event request data invalid object ID returns nil
    func test_12_MobileEventRequestData_invalidObjectID_returnsNil() {
        let exp = self.expectation(description: "Mobile event request completion")
        
        let entity = createMobileEventEntity()
        let invalidObjectID = entity.objectID
        
        let differentContext = newBGContext()
        
        getMobileEventRequestData(context: differentContext, objectID: invalidObjectID) { requestData in
            XCTAssertNil(requestData, "Expected nil for invalid object ID")
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
}

