//
//  AppVersionMatcherTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
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

/// Tests for app version matching.
final class AppVersionMatcherTests: XCTestCase {

    // MARK: - Operator fromValue

    /// test_1: fromValue returns correct operator for valid raw values
    func test_1_fromValue_returnsCorrectOperator_forValidRawValues() {
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("equal"), .equal)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("not_equal"), .notEqual)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("greater_than"), .greaterThan)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("less_than"), .lessThan)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("greater_e"), .greaterEqual)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("less_e"), .lessEqual)
    }

    /// test_2: fromValue is case-insensitive
    func test_2_fromValue_isCaseInsensitive() {
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("EQUAL"), .equal)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("Greater_Than"), .greaterThan)
        XCTAssertEqual(AppVersionMatcher.Operator.fromValue("LESS_E"), .lessEqual)
    }

    /// test_3: fromValue returns nil for unknown value
    func test_3_fromValue_returnsNil_forUnknownValue() {
        XCTAssertNil(AppVersionMatcher.Operator.fromValue("unknown"))
        XCTAssertNil(AppVersionMatcher.Operator.fromValue(""))
        XCTAssertNil(AppVersionMatcher.Operator.fromValue(nil))
    }

    // MARK: - matches with Operator enum

    /// test_4: equal operator matches identical versions
    func test_4_equal_matchesIdenticalVersions() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .equal
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.4"], operator: .equal
        ))
    }

    /// test_5: notEqual operator works correctly
    func test_5_notEqual_matchesDifferentVersions() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.4"], operator: .notEqual
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .notEqual
        ))
    }

    /// test_6: greaterThan operator works correctly
    func test_6_greaterThan_matchesGreaterVersions() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.4", appVersions: ["1.2.3"], operator: .greaterThan
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.2", appVersions: ["1.2.3"], operator: .greaterThan
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .greaterThan
        ))
    }

    /// test_7: lessThan operator works correctly
    func test_7_lessThan_matchesLesserVersions() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.2", appVersions: ["1.2.3"], operator: .lessThan
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.4", appVersions: ["1.2.3"], operator: .lessThan
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .lessThan
        ))
    }

    /// test_8: greaterEqual operator works correctly
    func test_8_greaterEqual_matchesGreaterOrEqual() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.4", appVersions: ["1.2.3"], operator: .greaterEqual
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .greaterEqual
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.2", appVersions: ["1.2.3"], operator: .greaterEqual
        ))
    }

    /// test_9: lessEqual operator works correctly
    func test_9_lessEqual_matchesLesserOrEqual() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.2", appVersions: ["1.2.3"], operator: .lessEqual
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3", appVersions: ["1.2.3"], operator: .lessEqual
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.4", appVersions: ["1.2.3"], operator: .lessEqual
        ))
    }

    // MARK: - version parsing edge cases

    /// test_10: version with v prefix is parsed correctly
    func test_10_parsesVersion_withVPrefix() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "v1.2.4", appVersions: ["v1.2.3"], operator: .greaterThan
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "v1.2.3", appVersions: ["v1.2.3"], operator: .equal
        ))
    }

    /// test_11: version with beta suffix is handled correctly
    func test_11_parsesVersion_withBetaSuffix() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3-beta", appVersions: ["1.2.3"], operator: .equal
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.4-beta", appVersions: ["1.2.3"], operator: .lessEqual
        ))
    }

    /// test_12: version with text prefix and multiple parts
    func test_12_parsesVersion_withTextPrefix() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "version 1.2.3", appVersions: ["1.2.3"], operator: .equal
        ))
    }

    /// test_13: trailing zero in last part is ignored
    func test_13_parsesVersion_trailingZeroIgnored() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.0", appVersions: ["1.2"], operator: .equal
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2", appVersions: ["1.2.0"], operator: .equal
        ))
    }

    /// test_14: empty version string returns false for equal
    func test_14_emptyVersion_returnsFalse_forEqual() {
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "", appVersions: ["1.0.0"], operator: .equal
        ))
    }

    /// test_15: matches any version in the list
    func test_15_matchesAnyVersion_inList() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.0.5",
            appVersions: ["1.0.0", "1.0.5", "2.0.0"],
            operator: .equal
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.0.6",
            appVersions: ["1.0.0", "1.0.5", "2.0.0"],
            operator: .equal
        ))
    }

    /// test_16: matches version with extra trailing parts
    func test_16_parsesVersion_withExtraTrailingParts() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "v4.3.1.1.213361",
            appVersions: ["4.3.1"],
            operator: .equal
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "v4.3.2.1.213361",
            appVersions: ["4.3.1"],
            operator: .greaterThan
        ))
    }

    // MARK: - matches with condition string

    /// test_17: matches with valid condition string delegates to operator
    func test_17_matches_withConditionString() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3",
            appVersions: ["1.2.3"],
            condition: "equal"
        ))
        XCTAssertFalse(AppVersionMatcher.matches(
            appVersion: "1.2.4",
            appVersions: ["1.2.3"],
            condition: "equal"
        ))
    }

    /// test_18: matches with invalid condition string returns true (fallback)
    func test_18_matches_withInvalidCondition_returnsTrue() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3",
            appVersions: ["1.2.3"],
            condition: "bogus"
        ))
    }

    /// test_19: matches with nil condition string returns true (fallback)
    func test_19_matches_withNilCondition_returnsTrue() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.2.3",
            appVersions: ["1.2.4"],
            condition: "nil"
        ))
    }

    /// test_20: major version comparison works
    func test_20_comparison_majorVersion() {
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "2.0.0", appVersions: ["1.9.9"], operator: .greaterThan
        ))
        XCTAssertTrue(AppVersionMatcher.matches(
            appVersion: "1.0.0", appVersions: ["2.0.0"], operator: .lessThan
        ))
    }
}
