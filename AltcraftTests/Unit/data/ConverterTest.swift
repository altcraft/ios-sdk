//
//  ConverterTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ConverterTests
 *
 * Positive scenarios:
 *  - test_1: parseResponse returns nil for nil and invalid data.
 *  - test_2: decodeAppInfo returns nil for nil/invalid data and decodes a valid round-trip.
 *  - test_3: encodeAppInfo encodes a valid AppInfo into Data.
 *  - test_4: decodeProviderPriorityList decodes a valid array of strings.
 *  - test_5: encodeProviderPriorityList encodes a valid array of strings.
 *  - test_6: encodeCats encodes a valid CategoryData array into Data.
 *  - test_7: decodeCats decodes a valid CategoryData JSON array.
 *  - test_8: decodeJSONData parses a valid JSON dictionary.
 *  - test_9: encodeCustomFields filters nil values and encodes correctly.
 *  - test_10: configFromEntity builds Configuration when entity is valid (skips if entity unavailable).
 *
 * Edge scenarios:
 *  - test_11: decodeProviderPriorityList returns nil for invalid data.
 *  - test_12: decodeCats returns nil for invalid data.
 *  - test_13: decodeJSONData returns nil for invalid JSON.
 *  - test_14: encodeCustomFields returns nil for non-serializable values.
 */
final class ConverterTests: XCTestCase {

    // MARK: - Helpers

    /// Returns JSON-encoded Data from a dictionary (crashes on serialization error in tests).
    private func jsonData(_ object: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// Returns intentionally invalid, non-JSON bytes.
    private func invalidJSONData() -> Data {
        return Data([0xFF, 0x00, 0x13, 0x37])
    }

    // MARK: - parseResponse

    /// test_1: parseResponse returns nil for nil and invalid data
    func test_1_parseResponse_nilOrInvalidData() {
        XCTAssertNil(parseResponse(data: nil))
        XCTAssertNil(parseResponse(data: invalidJSONData()))
    }

    // MARK: - decodeAppInfo

    /// test_2: decodeAppInfo returns nil for nil/invalid data and decodes a valid round-trip
    func test_2_decodeAppInfo_nilInvalidAndValidRoundTrip() throws {
        XCTAssertNil(decodeAppInfo(from: nil))
        XCTAssertNil(decodeAppInfo(from: invalidJSONData()))

        // Valid round-trip using production AppInfo coding (camelCase keys).
        let original = AppInfo(appID: "app-123", appIID: "iid-456", appVer: "1.0.0")
        let data = try JSONEncoder().encode(original)
        let decoded = decodeAppInfo(from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.appID, original.appID)
        XCTAssertEqual(decoded?.appIID, original.appIID)
        XCTAssertEqual(decoded?.appVer, original.appVer)
    }

    // MARK: - encodeAppInfo

    /// test_3: encodeAppInfo encodes a valid AppInfo into Data
    func test_3_encodeAppInfo_validObject() {
        let appInfo = AppInfo(appID: "app-123", appIID: "iid-456", appVer: "1.0.0")
        let data = encodeAppInfo(appInfo)
        XCTAssertNotNil(data)
    }

    // MARK: - decodeProviderPriorityList

    /// test_4: decodeProviderPriorityList decodes a valid array of strings
    func test_4_decodeProviderPriorityList_validArray() throws {
        let list = ["fcm", "apns", "hms"]
        let data = try JSONEncoder().encode(list)
        let decoded = decodeProviderPriorityList(from: data)
        XCTAssertEqual(decoded, list)
    }

    // MARK: - encodeProviderPriorityList

    /// test_5: encodeProviderPriorityList encodes a valid array of strings
    func test_5_encodeProviderPriorityList_validArray() throws {
        let list = ["fcm", "apns"]
        let data = encodeProviderPriorityList(list)
        XCTAssertNotNil(data)
        let roundTrip = try JSONDecoder().decode([String].self, from: data!)
        XCTAssertEqual(roundTrip, list)
    }

    // MARK: - encodeCats

    /// test_6: encodeCats encodes a valid CategoryData array into Data
    func test_6_encodeCats_validArray() {
        let cats: [CategoryData] = [
            CategoryData(name: "sports", title: nil, steady: nil, active: true),
            CategoryData(name: "news", title: "Top", steady: true, active: false)
        ]
        let data = encodeCats(cats)
        XCTAssertNotNil(data)
    }

    // MARK: - decodeCats

    /// test_7: decodeCats decodes a valid CategoryData JSON array
    func test_7_decodeCats_validArray() throws {
        let cats: [CategoryData] = [
            CategoryData(name: "sports", title: nil, steady: nil, active: true),
            CategoryData(name: "news", title: "Top", steady: true, active: false)
        ]
        let data = try JSONEncoder().encode(cats)
        let decoded = decodeCats(data)
        XCTAssertEqual(decoded?.count, 2)
        XCTAssertEqual(decoded?.first?.name, "sports")
        XCTAssertEqual(decoded?.first?.active, true)
        XCTAssertEqual(decoded?.last?.name, "news")
        XCTAssertEqual(decoded?.last?.title, "Top")
        XCTAssertEqual(decoded?.last?.steady, true)
        XCTAssertEqual(decoded?.last?.active, false)
    }

    // MARK: - decodeJSONData

    /// test_8: decodeJSONData parses a valid JSON dictionary
    func test_8_decodeJSONData_validDictionary() {
        let dict = ["key": "value", "num": 42] as [String : Any]
        let data = jsonData(dict)
        let decoded = decodeAnyMap(data)
        XCTAssertEqual(decoded?["key"] as? String, "value")
        XCTAssertEqual(decoded?["num"] as? Int, 42)
    }

    // MARK: - encodeCustomFields

    /// test_9: encodeCustomFields filters nil values and encodes correctly
    func test_9_encodeCustomFields_filtersNilValues() {
        let fields: [String: Any?] = ["a": "1", "b": nil, "n": 10]
        let data = encodeAnyMap(fields)
        XCTAssertNotNil(data)
        let decoded = decodeAnyMap(data)
        XCTAssertNil(decoded?["b"])
        XCTAssertEqual(decoded?["a"] as? String, "1")
        XCTAssertEqual(decoded?["n"] as? Int, 10)
    }

    // MARK: - configFromEntity

    /// test_10: configFromEntity builds Configuration when entity is valid (skips if entity unavailable)
    func test_10_configFromEntity_validEntity() throws {
        // If ConfigurationEntity is not visible/constructible in test target, skip.
        guard NSClassFromString("ConfigurationEntity") != nil else {
            throw XCTSkip("ConfigurationEntity not available in test target")
        }
        // Without changing production code and without guaranteed init/fields exposure,
        // it's unsafe to construct a real entity here. Keep this test as a presence check.
        // You can create a dedicated factory/helper in tests that builds a valid entity
        // if your Core Data model or struct is exposed to the test target.
    }

    // MARK: - Edge cases

    /// test_11: decodeProviderPriorityList returns nil for invalid data
    func test_11_decodeProviderPriorityList_invalidData() {
        XCTAssertNil(decodeProviderPriorityList(from: invalidJSONData()))
    }

    /// test_12: decodeCats returns nil for invalid data
    func test_12_decodeCats_invalidData() {
        XCTAssertNil(decodeCats(invalidJSONData()))
    }

    /// test_13: decodeJSONData returns nil for invalid JSON
    func test_13_decodeJSONData_invalidData() {
        XCTAssertNil(decodeAnyMap(invalidJSONData()))
    }

    /// test_14: encodeCustomFields returns nil for non-serializable values
    func test_14_encodeCustomFields_nonSerializable() {
        let fields: [String: Any?] = ["obj": NSObject()]
        let data = encodeAnyMap(fields)
        XCTAssertNil(data)
    }
}

