//
//  CollectorTests.swift
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
* CollectorTests
*
* Positive scenarios:
* - test_1: getAuthData with R token returns bearer R token.
* - test_2: PushSubscribeRequestData is valid for complete data.
* - test_3: PushEventRequestData is valid for allowed types.
* - test_4: decodeAnyMap decodes valid dictionary JSON.
* - test_8: TargetEventRequestData stores valid data successfully.
* - test_9: PartsFactory creates mobile event parts for all fields.
*
* Edge scenarios:
* - test_5: PushSubscribeRequestData is invalid when mandatory fields are missing.
* - test_6: PushEventRequestData is invalid for unsupported type and invalid fields.
* - test_7: decodeAnyMap returns nil for root array JSON.
* - test_11: PartsFactory creates mobile event parts for partial fields only.
* - test_12: getTargetEventRequestData returns nil for deleted object ID.
*
*/
final class CollectorTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override class var sdkManagerContainer: NSPersistentContainer? {
        targetDatabase.persistentContainer
    }

    private func createConfigurationEntity(
        url: String = "https://api.example.com",
        rToken: String = "rtoken-123"
    ) {
        let entity = ConfigurationEntity(context: viewContext)
        entity.url = url
        entity.rToken = rToken
        try? viewContext.save()
    }

    private func createTargetEntity(
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
    ) -> TargetEntity {
        let entity = TargetEntity(context: viewContext)
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

    private func jsonData(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// test_1: getAuthData with R token returns bearer R token
    func test_1_get_auth_data_with_r_token_returns_bearer_r_token() async {
        let token = "rTok123"
        let result = await getAuthData(rToken: token)

        XCTAssertNotNil(result, "Expected non-nil auth data when rToken is provided")
        XCTAssertEqual(result?.0, "Bearer rtoken@\(token)")
        XCTAssertEqual(result?.1, Constants.AuthKeys.rTokenMatching)
    }

    /// test_2: PushSubscribeRequestData is valid for complete data
    func test_2_push_subscribe_request_data_is_valid_for_complete_data() {
        let requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "uuid-1",
            time: 1_725_000_000,
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: true,
            profileFields: ["p": "v"],
            fields: ["c": "v"],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        XCTAssertTrue(requestData.isValid)
    }

    /// test_3: PushEventRequestData is valid for allowed types
    func test_3_push_event_request_data_is_valid_for_allowed_types() {
        var requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-1",
            time: 1_725_000_000,
            type: PushConstants.PushEvents.delivery,
            uid: "u1",
        )

        XCTAssertTrue(requestData.isValid)

        requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-2",
            time: 1_725_000_000,
            type: PushConstants.PushEvents.open,
            uid: "u2",
        )

        XCTAssertTrue(requestData.isValid)
    }

    /// test_4: decodeAnyMap decodes valid dictionary JSON
    func test_4_decode_any_map_decodes_valid_dictionary_json() throws {
        let dictionary = ["a": "1", "n": 10] as [String: Any]
        let data = try jsonData(dictionary)
        let decoded = decodeAnyMap(data)

        XCTAssertEqual(decoded?["a"] as? String, "1")
        XCTAssertEqual(decoded?["n"] as? Int, 10)
    }

    /// test_5: PushSubscribeRequestData is invalid when mandatory fields are missing
    func test_5_push_subscribe_request_data_is_invalid_when_mandatory_fields_are_missing() {
        var requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "",
            time: 1_725_000_000,
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "uuid-1",
            time: 0,
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "uuid-1",
            time: 1_725_000_000,
            provider: "",
            deviceToken: "token-xyz",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "uuid-1",
            time: 1_725_000_000,
            provider: "ios-apns",
            deviceToken: "",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "uuid-1",
            time: 1_725_000_000,
            provider: "ios-apns",
            deviceToken: "token-xyz",
            status: "",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        XCTAssertFalse(requestData.isValid)
    }

    /// test_6: PushEventRequestData is invalid for unsupported type and invalid fields
    func test_6_push_event_request_data_is_invalid_for_unsupported_type_and_invalid_fields() {
        var requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-3",
            time: 1_725_000_000,
            type: "clicked",
            uid: "u3",
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-4",
            time: 0,
            type: PushConstants.PushEvents.open,
            uid: "u3",
        )
        XCTAssertFalse(requestData.isValid)

        requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-5",
            time: 1_725_000_000,
            type: PushConstants.PushEvents.open,
            uid: "",
        )
        XCTAssertFalse(requestData.isValid)
    }

    /// test_7: decodeAnyMap returns nil for root array JSON
    func test_7_decode_any_map_returns_nil_for_root_array_json() throws {
        let data = try JSONSerialization.data(withJSONObject: [1, 2, 3], options: [])
        let decoded = decodeAnyMap(data)

        XCTAssertNil(decoded)
    }

    /// test_8: TargetEventRequestData stores valid data successfully
    func test_8_mobile_event_request_data_stores_valid_data_successfully() {
        let entity = createTargetEntity()

        let requestData = RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: "RID-M-1",
            sid: entity.sid!,
            name: entity.eventName!,
            parts: [],
        )

        XCTAssertEqual(requestData.sid, "test-sid")
        XCTAssertEqual(requestData.name, "test-event")
        XCTAssertEqual(requestData.path, TargetConstants.UrlPath.event)
        XCTAssertEqual(requestData.requestId, "RID-M-1")
        XCTAssertTrue(requestData.parts.isEmpty)
    }

    /// test_9: PartsFactory creates mobile event parts for all fields
    func test_9_parts_factory_creates_mobile_event_parts_for_all_fields() {
        let utmObject = UTM(
            campaign: "test-campaign",
            content: "test-content",
            keyword: "test-keyword",
            medium: "test-medium",
            source: "test-source",
            temp: "test-temp"
        )

        let utmData = encodeUTM(utmObject)
        let payloadData = try? JSONSerialization.data(withJSONObject: ["key": "value"])
        let matchingData = try? JSONSerialization.data(withJSONObject: ["match": "data"])
        let subscriptionData = try? JSONSerialization.data(withJSONObject: ["sub": "data"])
        let profileData = try? JSONSerialization.data(withJSONObject: ["profile": "field"])

        let entity = createTargetEntity(
            time: 1_725_000,
            utmTags: utmData,
            payload: payloadData,
            sendMessageId: "test-smid",
            matching: matchingData,
            subscription: subscriptionData,
            profileFields: profileData
        )

        let parts = PartsFactory.createTargetEventParts(from: entity)

        let timeZonePart = parts.first { $0.name == TargetConstants.TargetEvents.TIME_ZONE }
        XCTAssertEqual(timeZonePart?.data, Data("180".utf8))

        let timePart = parts.first { $0.name == TargetConstants.TargetEvents.TIME_MOB }
        XCTAssertEqual(timePart?.data, Data("1725000".utf8))

        let clientIDPart = parts.first { $0.name == TargetConstants.TargetEvents.ALTCRAFT_CLIENT_ID }
        XCTAssertEqual(clientIDPart?.data, Data("test-client-id".utf8))

        let eventNamePart = parts.first { $0.name == TargetConstants.TargetEvents.MOB_EVENT_NAME }
        XCTAssertEqual(eventNamePart?.data, Data("test-event".utf8))

        let matchingTypePart = parts.first { $0.name == TargetConstants.TargetEvents.MATCHING_TYPE }
        XCTAssertNotNil(matchingTypePart)
        XCTAssertEqual(matchingTypePart?.data, Data("test-matching".utf8))

        let utmCampaignPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_CAMPAIGN }
        XCTAssertNotNil(utmCampaignPart)
        XCTAssertEqual(utmCampaignPart?.data, Data("test-campaign".utf8))

        let utmContentPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_CONTENT }
        XCTAssertNotNil(utmContentPart)
        XCTAssertEqual(utmContentPart?.data, Data("test-content".utf8))

        let utmKeywordPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_KEYWORD }
        XCTAssertNotNil(utmKeywordPart)
        XCTAssertEqual(utmKeywordPart?.data, Data("test-keyword".utf8))

        let utmMediumPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_MEDIUM }
        XCTAssertNotNil(utmMediumPart)
        XCTAssertEqual(utmMediumPart?.data, Data("test-medium".utf8))

        let utmSourcePart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_SOURCE }
        XCTAssertNotNil(utmSourcePart)
        XCTAssertEqual(utmSourcePart?.data, Data("test-source".utf8))

        let utmTempPart = parts.first { $0.name == TargetConstants.TargetEvents.UTM_TEMP }
        XCTAssertNotNil(utmTempPart)
        XCTAssertEqual(utmTempPart?.data, Data("test-temp".utf8))

        let jsonParts = parts.filter { $0.mime.contains("application/json") }
        XCTAssertEqual(jsonParts.count, 5)

        XCTAssertEqual(parts.count, 16)
    }

    /// test_11: PartsFactory creates mobile event parts for partial fields only
    func test_11_parts_factory_creates_mobile_event_parts_for_partial_fields_only() {
        let entity = createTargetEntity(
            matchingType: nil,
            utmTags: nil,
            payload: nil,
            sendMessageId: nil,
            matching: nil,
            subscription: nil,
            profileFields: nil
        )

        let parts = PartsFactory.createTargetEventParts(from: entity)

        XCTAssertEqual(parts.count, 4)

        let matchingTypePart = parts.first { $0.name == TargetConstants.TargetEvents.MATCHING_TYPE }
        XCTAssertNil(matchingTypePart)

        let payloadPart = parts.first { $0.name == TargetConstants.TargetEvents.PAYLOAD }
        XCTAssertNil(payloadPart)
    }

    /// test_12: getTargetEventRequestData returns nil for deleted object ID
    func test_12_get_mobile_event_request_data_returns_nil_for_deleted_object_id() async {
        let deletedObjectID: NSManagedObjectID = {
            let entity = createTargetEntity()
            return entity.objectID
        }()

        let viewContext = self.viewContext

        viewContext.performAndWait {
            let object = viewContext.object(with: deletedObjectID)
            viewContext.delete(object)
            try? viewContext.save()
        }

        let differentContext = newBGContext()

        let requestData = await getTargetEventRequestData(
            context: differentContext,
            objectID: deletedObjectID
        )

        XCTAssertNil(requestData)
    }
}
