//
//  CreateMessageTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * StringBuilderTest
 *
 * Positive scenarios:
 *  - test_1: formatFunctionName with single parameter → collapses parameters to "()".
 *  - test_2: formatFunctionName with multiple parameters → collapses all parameters to "()".
 *  - test_3: formatFunctionName without parameters → keeps function name unchanged.
 *  - test_4: subscribeURL with base URL → builds correct subscription endpoint.
 *  - test_5: updateUrl with base URL → builds correct update endpoint.
 *  - test_6: unSuspendUrl with base URL → builds correct unsuspend endpoint.
 *  - test_7: profileUrl with base URL → builds correct status endpoint.
 *  - test_8: eventMobileURL with base URL → builds correct mobile event endpoint.
 *  - test_9: pushEventURL with event type → appends event type to push event endpoint.
 *  - test_10: matchingAsString with valid parameters → returns properly formatted JSON with all key-value pairs.
 *  - test_11: pushEventURL with empty event type → handles gracefully and builds endpoint without type.
 *  - test_13: formatFunctionName with empty parentheses → keeps empty parentheses unchanged.
 *
 * Edge scenarios:
 *  - test_12: formatFunctionName with complex nested parameters → 
 *  handles based on current implementation (replaces only first parameter group).
 */
final class StringBuilderTest: IsolatedTestCase {

    private let baseURL = "https://pxl.altcraft.com"

    /// Collapses single parameter to "()"
    func test_1_formatFunctionName_collapsesSingleParam() {
        let input = "pushSubscribe(message: String)"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "pushSubscribe()")
    }

    /// Collapses multiple parameters to "()"
    func test_2_formatFunctionName_collapsesMultiParam() {
        let input = "fn(arg1: Int, arg2: String)"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "fn()")
    }

    /// Keeps names without parentheses unchanged
    func test_3_formatFunctionName_keepsNameWithoutParens() {
        let input = "simpleFn"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "simpleFn")
    }

    /// Handles complex function patterns based on actual implementation
    func test_12_formatFunctionName_handlesComplexPatterns() {
        let input = "func(a: (Int, String), b: [String: Any])"
        let result = formatFunctionName(input)
    
        XCTAssertEqual(result, "func(), b: [String: Any])")
    }

    /// Tests function with no parameters (empty parentheses)
    func test_13_formatFunctionName_handlesEmptyParameters() {
        let input = "function()"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "function()")
    }

    /// subscribeURL builds expected endpoint
    func test_4_subscribeURL_buildsExpectedEndpoint() {
        let result = subscribeURL(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/subscribe/")
    }

    /// updateUrl builds expected endpoint
    func test_5_updateUrl_buildsExpectedEndpoint() {
        let result = updateUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/update/")
    }

    /// unSuspendUrl builds expected endpoint
    func test_6_unSuspendUrl_buildsExpectedEndpoint() {
        let result = unSuspendUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/unsuspend/")
    }

    /// profileUrl builds expected endpoint
    func test_7_profileUrl_buildsExpectedEndpoint() {
        let result = profileUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/status/")
    }

    /// eventMobileURL builds expected endpoint
    func test_8_eventMobileURL_buildsExpectedEndpoint() {
        let result = eventMobileURL(baseURL)
        XCTAssertEqual(result, "\(baseURL)/event/post")
    }
    
    /// pushEventURL appends event type correctly
    func test_9_pushEventURL_appendsEventType() {
        let event = createPushEventEntity(type: "delivery")
        let result = eventPushURL(baseURL, event: event)
        XCTAssertEqual(result, "\(baseURL)/event/push/delivery")
    }

    /// pushEventURL handles empty event type gracefully
    func test_11_pushEventURL_handlesEmptyEventType() {
        let event = createPushEventEntity(type: "")
        let result = eventPushURL(baseURL, event: event)
        XCTAssertEqual(result, "\(baseURL)/event/push/")
    }

    /// matchingAsString returns valid JSON with expected structure
    func test_10_matchingAsString_returnsValidJsonAndPairs() throws {
        let dbId = 42
        let matching = "email"
        let value = "user@example.com"

        let jsonString = matchingAsString(dbId: dbId, matching: matching, value: value)
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(jsonObject?[Constants.AuthKeys.dbId] as? String, "42")
        XCTAssertEqual(jsonObject?[Constants.AuthKeys.matching] as? String, "email")
        XCTAssertEqual(jsonObject?[Constants.AuthKeys.matchingID] as? String, "user@example.com")
    }

    private func createPushEventEntity(type: String) -> PushEventEntity {
        let entity = PushEventEntity(context: viewContext)
        entity.type = type
        return entity
    }
}
