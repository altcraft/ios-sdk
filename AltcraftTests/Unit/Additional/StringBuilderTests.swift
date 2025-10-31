//
//  CreateMessageTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * StringBuilderTests
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

final class StringBuilderTests: IsolatedTestCase {

    private let baseURL = "https://pxl.altcraft.com"

    /// test_1: formatFunctionName with single parameter collapses parameters to "()"
    func test_1_formatFunctionName_collapsesSingleParam() {
        let input = "pushSubscribe(message: String)"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "pushSubscribe()")
    }

    /// test_2: formatFunctionName with multiple parameters collapses all parameters to "()"
    func test_2_formatFunctionName_collapsesMultiParam() {
        let input = "fn(arg1: Int, arg2: String)"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "fn()")
    }

    /// test_3: formatFunctionName without parameters keeps function name unchanged
    func test_3_formatFunctionName_keepsNameWithoutParens() {
        let input = "simpleFn"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "simpleFn")
    }

    /// test_12: formatFunctionName with complex nested parameters handles based on current implementation
    func test_12_formatFunctionName_handlesComplexPatterns() {
        let input = "func(a: (Int, String), b: [String: Any])"
        let result = formatFunctionName(input)
    
        XCTAssertEqual(result, "func(), b: [String: Any])")
    }

    /// test_13: formatFunctionName with empty parentheses keeps empty parentheses unchanged
    func test_13_formatFunctionName_handlesEmptyParameters() {
        let input = "function()"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "function()")
    }

    /// test_4: subscribeURL with base URL builds correct subscription endpoint
    func test_4_subscribeURL_buildsExpectedEndpoint() {
        let result = subscribeURL(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/subscribe/")
    }

    /// test_5: updateUrl with base URL builds correct update endpoint
    func test_5_updateUrl_buildsExpectedEndpoint() {
        let result = updateUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/update/")
    }

    /// test_6: unSuspendUrl with base URL builds correct unsuspend endpoint
    func test_6_unSuspendUrl_buildsExpectedEndpoint() {
        let result = unSuspendUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/unsuspend/")
    }

    /// test_7: profileUrl with base URL builds correct status endpoint
    func test_7_profileUrl_buildsExpectedEndpoint() {
        let result = profileUrl(baseURL)
        XCTAssertEqual(result, "\(baseURL)/subscription/push/status/")
    }

    /// test_8: eventMobileURL with base URL builds correct mobile event endpoint
    func test_8_eventMobileURL_buildsExpectedEndpoint() {
        let result = eventMobileURL(baseURL)
        XCTAssertEqual(result, "\(baseURL)/event/post")
    }
    
    /// test_9: pushEventURL with event type appends event type to push event endpoint
    func test_9_pushEventURL_appendsEventType() {
        let event = createPushEventEntity(type: "delivery")
        let result = eventPushURL(baseURL, event: event)
        XCTAssertEqual(result, "\(baseURL)/event/push/delivery")
    }

    /// test_11: pushEventURL with empty event type handles gracefully and builds endpoint without type
    func test_11_pushEventURL_handlesEmptyEventType() {
        let event = createPushEventEntity(type: "")
        let result = eventPushURL(baseURL, event: event)
        XCTAssertEqual(result, "\(baseURL)/event/push/")
    }

    /// test_10: matchingAsString with valid parameters returns properly formatted JSON with all key-value pairs
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
