//
//  MapBuilderTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * MapBuilderTests
 *
 * Positive scenarios:
 *  - test_1: mapValue with all parameters → includes uid, type, name and wraps http code/response in ResponseWithHttp.
 *  - test_2: mapValue with no parameters → omits uid/type/name but still includes ResponseWithHttp wrapper with nil values.
 *  - test_3: mapValue with only name parameter → includes name in map and omits other optional fields.
 *  - test_4: mergeFields with multiple dictionaries → merges entries and later values override earlier ones.
 *  - test_5: mergeFields with nil value → removes the key from resulting dictionary.
 *  - test_6: mergeFields with many conflicting entries → last provided value wins across all keys.
 *  - test_7: mergeFields with empty input → returns empty dictionary.
 *  - test_8: mergeFields with single dictionary → returns same dictionary unchanged.
 */

final class MapBuilderTests: XCTestCase {

    private let inputUid = "u-123"
    private let inputType = "delivery"
    private let inputName = "test_event"
    private let httpCodeOK = 200

    private let keyA = "a"
    private let keyB = "b"
    private let keyC = "c"
    private let keyK = "k"
    private let keyX = "x"
    private let keyY = "y"

    /// test_1: mapValue with all parameters includes uid, type, name and wraps http code/response in ResponseWithHttp
    func test_1_mapValue_includesUidTypeAndResponseWrapper() {
        let response: Response? = nil

        let map = mapValue(
            code: httpCodeOK,
            response: response,
            uid: inputUid,
            type: inputType,
            name: inputName
        )

        XCTAssertEqual(map[Constants.MapKeys.uid] as? String, inputUid)
        XCTAssertEqual(map[Constants.MapKeys.type] as? String, inputType)
        XCTAssertEqual(map[Constants.MapKeys.name] as? String, inputName)

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper missing")
            return
        }
        XCTAssertEqual(wrapped.httpCode, httpCodeOK)
        XCTAssertNil(wrapped.response)
    }

    /// test_2: mapValue with no parameters omits uid/type/name but still includes ResponseWithHttp wrapper with nil values
    func test_2_mapValue_omitsMissingKeys_butIncludesWrapper() {
        let map = mapValue()

        XCTAssertNil(map[Constants.MapKeys.uid])
        XCTAssertNil(map[Constants.MapKeys.type])
        XCTAssertNil(map[Constants.MapKeys.name])

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper must be present")
            return
        }
        XCTAssertNil(wrapped.httpCode)
        XCTAssertNil(wrapped.response)
    }

    /// test_3: mapValue with only name parameter includes name in map and omits other optional fields
    func test_3_mapValue_includesNameWhenProvided() {
        let map = mapValue(name: inputName)

        XCTAssertEqual(map[Constants.MapKeys.name] as? String, inputName)
        XCTAssertNil(map[Constants.MapKeys.uid])
        XCTAssertNil(map[Constants.MapKeys.type])

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper must be present")
            return
        }
        XCTAssertNil(wrapped.httpCode)
        XCTAssertNil(wrapped.response)
    }

    /// test_4: mergeFields with multiple dictionaries merges entries and later values override earlier ones
    func test_4_mergeFields_mergesAndOverrides() {
        let a: [String: Any?] = [keyA: 1, keyB: "x"]
        let b: [String: Any?] = [keyB: "y", keyC: true]

        let merged = mergeFields(a, b)

        XCTAssertEqual(merged[keyA] as? Int, 1)
        XCTAssertEqual(merged[keyB] as? String, "y")
        XCTAssertEqual(merged[keyC] as? Bool, true)
    }

    /// test_5: mergeFields with nil value removes the key from resulting dictionary
    func test_5_mergeFields_nilRemovesKey() {
        let base: [String: Any?] = [keyA: 1, keyB: 2]
        let removal: [String: Any?] = [keyA: nil]

        let merged = mergeFields(base, removal)

        XCTAssertNil(merged[keyA] ?? nil)
        XCTAssertEqual(merged[keyB] as? Int, 2)
    }

    /// test_6: mergeFields with many conflicting entries last provided value wins across all keys
    func test_6_mergeFields_lastWinsWithManyEntries() {
        let m1: [String: Any?] = [keyK: "v1", keyX: 1]
        let m2: [String: Any?] = [keyK: nil, keyX: 2]
        let m3: [String: Any?] = [keyK: "v3", keyY: true]

        let merged = mergeFields(m1, m2, m3)

        XCTAssertEqual(merged[keyK] as? String, "v3")
        XCTAssertEqual(merged[keyX] as? Int, 2)
        XCTAssertEqual(merged[keyY] as? Bool, true)
    }

    /// test_7: mergeFields with empty input returns empty dictionary
    func test_7_mergeFields_emptyInputReturnsEmpty() {
        let merged = mergeFields()
        XCTAssertTrue(merged.isEmpty)
    }

    /// test_8: mergeFields with single dictionary returns same dictionary unchanged
    func test_8_mergeFields_singleDictionaryReturnsSame() {
        let input: [String: Any?] = [keyA: 1, keyB: "test"]
        let merged = mergeFields(input)
        XCTAssertEqual(merged[keyA] as? Int, 1)
        XCTAssertEqual(merged[keyB] as? String, "test")
    }
}
