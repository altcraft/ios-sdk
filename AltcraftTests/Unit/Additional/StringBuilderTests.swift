//
//  StringBuilderTests.swift
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
 * StringBuilderTests
 *
 * Positive scenarios:
 *  - test_1: formatFunctionName with single parameter → collapses parameters to "()".
 *  - test_2: formatFunctionName with multiple parameters → collapses all parameters to "()".
 *  - test_3: formatFunctionName without parameters → keeps function name unchanged.
 *  - test_10: matchingAsString with valid parameters → returns properly formatted JSON with all key-value pairs.
 *  - test_13: formatFunctionName with empty parentheses → keeps empty parentheses unchanged.
 *  - test_14: matchingAsString with special characters in value → escapes them without corrupting JSON.
 *
 * Edge scenarios:
 *  - test_12: formatFunctionName with complex nested parameters →
 *  handles based on current implementation (replaces only first parameter group).
 */

final class StringBuilderTests: IsolatedTestCase {

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

    /// test_12: formatFunctionName with complex nested parameters collapses all params to "()"
    func test_12_formatFunctionName_handlesComplexPatterns() {
        let input = "func(a: (Int, String), b: [String: Any])"
        let result = formatFunctionName(input)
    
        XCTAssertEqual(result, "func()")
    }

    /// test_13: formatFunctionName with empty parentheses keeps empty parentheses unchanged
    func test_13_formatFunctionName_handlesEmptyParameters() {
        let input = "function()"
        let result = formatFunctionName(input)
        XCTAssertEqual(result, "function()")
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

    /// test_14: matchingAsString escapes special characters in value without corrupting JSON
    func test_14_matchingAsString_escapesSpecialCharacters() throws {
        let value = "a\"b\\c\nd\te"

        let jsonString = matchingAsString(dbId: 1, matching: "email", value: value)
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(jsonObject?[Constants.AuthKeys.matchingID] as? String, value)
    }
}
