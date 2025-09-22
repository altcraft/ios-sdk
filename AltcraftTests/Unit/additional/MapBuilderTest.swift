//
//  MapBuilderTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * MapBuilderTest
 *
 * Positive scenarios:
 *  - test_1: mapValue includes uid/type when provided and wraps code/response into ResponseWithHttp.
 *  - test_2: mapValue omits uid/type when missing but still provides ResponseWithHttp wrapper.
 *  - test_3: mergeFields merges multiple dictionaries and later values override earlier ones.
 *
 * Edge scenarios:
 *  - test_4: mergeFields with nil value removes the key in the resulting dictionary.
 *  - test_5: mergeFields "last wins" across many conflicting entries.
 */
final class MapBuilderTest: XCTestCase {

    // ---------- Test inputs ----------
    private let inputUid   = "u-123"
    private let inputType  = "delivery"
    private let httpCodeOK = 200

    // Keys used in ad-hoc maps for merge tests
    private let keyA = "a"
    private let keyB = "b"
    private let keyC = "c"
    private let keyK = "k"
    private let keyX = "x"
    private let keyY = "y"

    // ---------- Assertion messages ----------
    private let msgWrapperMissing   = "responseWithHttp is missing or has wrong type"
    private let msgUidAbsent        = "uid must be absent when not provided"
    private let msgTypeAbsent       = "type must be absent when not provided"
    private let msgLastWins         = "later dictionary must override earlier value"
    private let msgKeyShouldBeLast  = "'k' must be the last provided non-nil value"
    private let msgXOverridden      = "'x' overridden by later map"

    // ---------------------------------
    // mapValue(..)
    // ---------------------------------

    /// test_1: includes uid/type and wraps http code/response
    func test_1_mapValue_includesUidTypeAndResponseWrapper() {
        // Given
        let response: Response? = nil // wrapper should still be created

        // When
        let map = mapValue(code: httpCodeOK, response: response, uid: inputUid, type: inputType)

        // Then
        XCTAssertEqual(map[Constants.MapKeys.uid] as? String, inputUid)
        XCTAssertEqual(map[Constants.MapKeys.type] as? String, inputType)

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail(msgWrapperMissing)
            return
        }
        XCTAssertEqual(wrapped.httpCode, httpCodeOK)
        XCTAssertNil(wrapped.response)
    }

    /// test_2: omits uid/type when not provided, but still includes ResponseWithHttp with nil httpCode
    func test_2_mapValue_omitsMissingKeys_butIncludesWrapper() {
        // When
        let map = mapValue() // defaults: code=nil, response=nil, uid=nil, type=nil

        // Then
        XCTAssertNil(map[Constants.MapKeys.uid],  msgUidAbsent)
        XCTAssertNil(map[Constants.MapKeys.type], msgTypeAbsent)

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper must be present")
            return
        }
        XCTAssertNil(wrapped.httpCode)
        XCTAssertNil(wrapped.response)
    }

    // ---------------------------------
    // mergeFields(..)
    // ---------------------------------

    /// test_3: merges and later entries override earlier ones
    func test_3_mergeFields_mergesAndOverrides() {
        // Given
        let a: [String: Any?] = [keyA: 1, keyB: "x"]
        let b: [String: Any?] = [keyB: "y", keyC: true]

        // When
        let merged = mergeFields(a, b)

        // Then
        XCTAssertEqual(merged[keyA] as? Int, 1)
        XCTAssertEqual(merged[keyB] as? String, "y", msgLastWins)
        XCTAssertEqual(merged[keyC] as? Bool, true)
    }

    /// test_4: nil value removes the key in a [String: Any?] dictionary
    func test_4_mergeFields_nilRemovesKey() {
        // Given
        let base:    [String: Any?] = [keyA: 1, keyB: 2]
        let removal: [String: Any?] = [keyA: nil] // nil should remove keyA

        // When
        let merged = mergeFields(base, removal)

        // Then
        XCTAssertNil(merged[keyA] ?? nil, "Key '\(keyA)' must be absent after merging nil")
        XCTAssertEqual(merged[keyB] as? Int, 2)
    }

    /// test_5: last wins across many conflicting entries (including nil in the middle)
    func test_5_mergeFields_lastWinsWithManyEntries() {
        // Given
        let m1: [String: Any?] = [keyK: "v1", keyX: 1]
        let m2: [String: Any?] = [keyK: nil,  keyX: 2]   
        let m3: [String: Any?] = [keyK: "v3", keyY: true]

        // When
        let merged = mergeFields(m1, m2, m3)

        // Then
        XCTAssertEqual(merged[keyK] as? String, "v3", msgKeyShouldBeLast)
        XCTAssertEqual(merged[keyX] as? Int, 2,     msgXOverridden)
        XCTAssertEqual(merged[keyY] as? Bool, true)
    }
}

