//
//  GeneratorTests.swift
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

/// Tests for generator utilities.
final class GeneratorTests: XCTestCase {

    /// test_1: getNano12 returns 12-character string
    func test_1_getNano12_returns12CharacterString() {
        let result = getNano12()
        XCTAssertEqual(result.count, 12)
    }

    /// test_2: getNano12 returns different values on each call
    func test_2_getNano12_returnsDifferentValues_onEachCall() {
        let a = getNano12()
        let b = getNano12()
        XCTAssertNotEqual(a, b)
    }

    /// test_3: getNano12 contains only alphanumeric characters
    func test_3_getNano12_containsOnlyAlphanumerics() {
        let result = getNano12()
        let allowed = CharacterSet.alphanumerics
        XCTAssertTrue(result.unicodeScalars.allSatisfy { allowed.contains($0) })
    }

    /// test_4: generateUUID returns a valid UUID string
    func test_4_generateUUID_returnsValidUUID() {
        let result = generateUUID()
        XCTAssertNotNil(UUID(uuidString: result))
    }

    /// test_5: generateUUID returns different values on each call
    func test_5_generateUUID_returnsDifferentValues_onEachCall() {
        let a = generateUUID()
        let b = generateUUID()
        XCTAssertNotEqual(a, b)
    }

    /// test_6: getCurrentTimeMillis returns a reasonable value (after year 2020)
    func test_6_getCurrentTimeMillis_returnsReasonableValue() {
        let result = getCurrentTimeMillis()
        let year2020Millis: Int64 = 1_577_836_800_000
        XCTAssertGreaterThan(result, year2020Millis)
    }

    /// test_7: getCurrentTimeMillis is monotonic (subsequent calls increase)
    func test_7_getCurrentTimeMillis_isMonotonic() {
        let a = getCurrentTimeMillis()
        let b = getCurrentTimeMillis()
        XCTAssertGreaterThanOrEqual(b, a)
    }
}
