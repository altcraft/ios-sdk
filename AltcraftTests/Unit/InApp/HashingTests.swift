//
//  HashingTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CryptoKit
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
 * HashingTests
 *
 * Positive scenarios:
 *  - test_1: sha256 produces known digest for known input.
 *  - test_2: sha256 produces correct digest for empty string.
 *  - test_3: sha256 output is lowercase hex.
 *  - test_4: sha256 is deterministic (same input yields same output).
 *  - test_5: sha256 produces different digest for different input.
 */
final class HashingTests: XCTestCase {

    /// test_1: sha256 produces known digest for known input
    func test_1_sha256_knownDigest_forKnownInput() {
        let input = "hello"
        let expected = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        XCTAssertEqual(sha256(input), expected)
    }

    /// test_2: sha256 produces correct digest for empty string
    func test_2_sha256_correctDigest_forEmptyString() {
        let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        XCTAssertEqual(sha256(""), expected)
    }

    /// test_3: sha256 output is lowercase hex
    func test_3_sha256_outputIsLowercaseHex() {
        let result = sha256("ABC")
        XCTAssertEqual(result, result.lowercased())
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        XCTAssertNil(result.rangeOfCharacter(from: hexChars.inverted))
        XCTAssertEqual(result.count, 64)
    }

    /// test_4: sha256 is deterministic (same input yields same output)
    func test_4_sha256_isDeterministic() {
        let input = "deterministic-test"
        let a = sha256(input)
        let b = sha256(input)
        XCTAssertEqual(a, b)
    }

    /// test_5: sha256 produces different digest for different input
    func test_5_sha256_differentDigest_forDifferentInput() {
        XCTAssertNotEqual(sha256("foo"), sha256("bar"))
    }
}
