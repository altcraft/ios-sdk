//
//  RepositoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * RepositoryTests
 *
 * Positive scenarios:
 *  - test_1_getAuthData_withRToken_returnsBearerRToken: getAuthData builds a Bearer header from a non-empty rToken.
 *  - test_2_SubscribeRequestData_isValid_success: SubscribeRequestData.isValid returns true for a fully populated request.
 *  - test_3_PushEventRequestData_isValid_allowedTypes: PushEventRequestData.isValid accepts only allowed types.
 *  - test_4_decodeJSONData_validDictionary: decodeJSONData parses a valid JSON dictionary.
 *
 * Edge scenarios:
 *  - test_5_SubscribeRequestData_isValid_missingMandatoryFields: SubscribeRequestData.isValid returns false for missing/empty required fields.
 *  - test_6_PushEventRequestData_isValid_invalidType: PushEventRequestData.isValid rejects non-allowed type values.
 *  - test_7_decodeJSONData_rootArray_returnsNil: decodeJSONData returns nil if JSON root is an array.
 *
 * Notes:
 *  - Async functions like getCommonData / getSubscribeRequestData / getUpdateRequestData /
 *    getPushEventRequestData / getUnSuspendRequestData / getProfileRequestData are not covered here,
 *    because they depend on external singletons and free functions without DI hooks.
 *    To test them, introduce protocols for dependencies (TokenManager, Config accessors, etc.)
 *    and inject test doubles in unit tests.
 */
final class RepositoryTests: XCTestCase {

    // MARK: - Helpers

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

    // MARK: - SubscribeRequestData.isValid

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
        // Empty requestId
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

        // Zero time
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

        // Empty authHeader
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

        // Empty matchingMode
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

        // Empty provider
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

        // Empty deviceToken
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

    // MARK: - PushEventRequestData.isValid

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
        // Invalid type: "clicked"
        var req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 1_725_000_000,
            type: "clicked",
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false for non-allowed type")

        // Invalid because of zero time
        req = PushEventRequestData(
            url: "https://api.example.com/push",
            time: 0,
            type: Constants.PushEvents.open,
            uid: "u3",
            authHeader: "Bearer abc",
            matchingMode: "m"
        )
        XCTAssertFalse(req.isValid(), "Expected false when time is 0")

        // Invalid because of empty uid
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

    // MARK: - decodeJSONData

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
}

