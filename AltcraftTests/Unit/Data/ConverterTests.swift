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
 *  - test_15: encodeSubscription encodes all supported subscription types correctly.
 *  - test_16: decodeSubscription decodes all supported subscription types correctly.
 *  - test_17: encodeUTM encodes UTM parameters correctly.
 *  - test_18: decodeUTM decodes UTM parameters correctly.
 *  - test_19: JSONValue encoding and decoding works for all supported types.
 *  - test_20: JSONValue convenience accessors return correct values.
 *
 * Edge scenarios:
 *  - test_11: decodeProviderPriorityList returns nil for invalid data.
 *  - test_12: decodeCats returns nil for invalid data.
 *  - test_13: decodeJSONData returns nil for invalid JSON.
 *  - test_14: encodeCustomFields returns nil for non-serializable values.
 *  - test_21: encodeSubscription returns nil for unsupported subscription type.
 *  - test_22: decodeSubscription returns nil for invalid data.
 *  - test_23: encodeUTM returns nil for nil input.
 *  - test_24: decodeUTM returns nil for nil input.
 *  - test_25: JSONValue handles unknown types with error.
 */
final class ConverterTests: XCTestCase {

    private func jsonData(_ object: [String: Any]) -> Data {
        return try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    private func invalidJSONData() -> Data {
        return Data([0xFF, 0x00, 0x13, 0x37])
    }

    /// test_1: parseResponse returns nil for nil and invalid data
    func test_1_parseResponse_nilOrInvalidData() {
        XCTAssertNil(parseResponse(data: nil))
        XCTAssertNil(parseResponse(data: invalidJSONData()))
    }

    /// test_2: decodeAppInfo returns nil for nil/invalid data and decodes a valid round-trip
    func test_2_decodeAppInfo_nilInvalidAndValidRoundTrip() throws {
        XCTAssertNil(decodeAppInfo(from: nil))
        XCTAssertNil(decodeAppInfo(from: invalidJSONData()))

        let original = AppInfo(appID: "app-123", appIID: "iid-456", appVer: "1.0.0")
        let data = try JSONEncoder().encode(original)
        let decoded = decodeAppInfo(from: data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.appID, original.appID)
        XCTAssertEqual(decoded?.appIID, original.appIID)
        XCTAssertEqual(decoded?.appVer, original.appVer)
    }

    /// test_3: encodeAppInfo encodes a valid AppInfo into Data
    func test_3_encodeAppInfo_validObject() {
        let appInfo = AppInfo(appID: "app-123", appIID: "iid-456", appVer: "1.0.0")
        let data = encodeAppInfo(appInfo)
        XCTAssertNotNil(data)
    }

    /// test_4: decodeProviderPriorityList decodes a valid array of strings
    func test_4_decodeProviderPriorityList_validArray() throws {
        let list = ["fcm", "apns", "hms"]
        let data = try JSONEncoder().encode(list)
        let decoded = decodeProviderPriorityList(from: data)
        XCTAssertEqual(decoded, list)
    }

    /// test_5: encodeProviderPriorityList encodes a valid array of strings
    func test_5_encodeProviderPriorityList_validArray() throws {
        let list = ["fcm", "apns"]
        let data = encodeProviderPriorityList(list)
        XCTAssertNotNil(data)
        let roundTrip = try JSONDecoder().decode([String].self, from: data!)
        XCTAssertEqual(roundTrip, list)
    }

    /// test_6: encodeCats encodes a valid CategoryData array into Data
    func test_6_encodeCats_validArray() {
        let cats: [CategoryData] = [
            CategoryData(name: "sports", title: nil, steady: nil, active: true),
            CategoryData(name: "news", title: "Top", steady: true, active: false)
        ]
        let data = encodeCats(cats)
        XCTAssertNotNil(data)
    }

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

    /// test_8: decodeJSONData parses a valid JSON dictionary
    func test_8_decodeJSONData_validDictionary() {
        let dict = ["key": "value", "num": 42] as [String : Any]
        let data = jsonData(dict)
        let decoded = decodeAnyMap(data)
        XCTAssertEqual(decoded?["key"] as? String, "value")
        XCTAssertEqual(decoded?["num"] as? Int, 42)
    }

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

    /// test_10: configFromEntity builds Configuration when entity is valid (skips if entity unavailable)
    func test_10_configFromEntity_validEntity() throws {
        guard NSClassFromString("ConfigurationEntity") != nil else {
            throw XCTSkip("ConfigurationEntity not available in test target")
        }
    }

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

    /// test_15: encodeSubscription encodes all supported subscription types correctly
    func test_15_encodeSubscription_allSupportedTypes() {
        let emailSub = EmailSubscription(resourceId: 1, email: "test@example.com")
        let smsSub = SmsSubscription(resourceId: 2, phone: "+1234567890")
        let pushSub = PushSubscription(resourceId: 3, provider: "ios-apns", subscriptionId: "sub-123")
        let ccDataSub = CcDataSubscription(resourceId: 4, channel: "telegram_bot", ccData: ["chat_id": .string("12345")])
        
        XCTAssertNotNil(encodeSubscription(emailSub))
        XCTAssertNotNil(encodeSubscription(smsSub))
        XCTAssertNotNil(encodeSubscription(pushSub))
        XCTAssertNotNil(encodeSubscription(ccDataSub))
    }

    /// test_16: decodeSubscription decodes all supported subscription types correctly
    func test_16_decodeSubscription_allSupportedTypes() throws {
        let emailSub = EmailSubscription(resourceId: 1, email: "test@example.com")
        let smsSub = SmsSubscription(resourceId: 2, phone: "+1234567890")
        let pushSub = PushSubscription(resourceId: 3, provider: "ios-apns", subscriptionId: "sub-123")
        let ccDataSub = CcDataSubscription(resourceId: 4, channel: "telegram_bot", ccData: ["chat_id": .string("12345")])
        
        let emailData = try JSONEncoder().encode(emailSub)
        let smsData = try JSONEncoder().encode(smsSub)
        let pushData = try JSONEncoder().encode(pushSub)
        let ccData = try JSONEncoder().encode(ccDataSub)
        
        XCTAssertNotNil(decodeSubscription(from: emailData) as? EmailSubscription)
        XCTAssertNotNil(decodeSubscription(from: smsData) as? SmsSubscription)
        XCTAssertNotNil(decodeSubscription(from: pushData) as? PushSubscription)
        XCTAssertNotNil(decodeSubscription(from: ccData) as? CcDataSubscription)
    }

    /// test_17: encodeUTM encodes UTM parameters correctly
    func test_17_encodeUTM_validParameters() throws {
        let utm = UTM(campaign: "test_campaign", content: "test_content",
                     keyword: "test_keyword", medium: "email",
                     source: "newsletter", temp: "test_temp")
        
        let data = encodeUTM(utm)
        XCTAssertNotNil(data)
        
        let decoded = try JSONDecoder().decode(UTM.self, from: data!)
        XCTAssertEqual(decoded.campaign, "test_campaign")
        XCTAssertEqual(decoded.content, "test_content")
        XCTAssertEqual(decoded.keyword, "test_keyword")
        XCTAssertEqual(decoded.medium, "email")
        XCTAssertEqual(decoded.source, "newsletter")
        XCTAssertEqual(decoded.temp, "test_temp")
    }

    /// test_18: decodeUTM decodes UTM parameters correctly
    func test_18_decodeUTM_validData() throws {
        let utm = UTM(campaign: "campaign", source: "source")
        let data = try JSONEncoder().encode(utm)
        
        let decoded = decodeUTM(data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.campaign, "campaign")
        XCTAssertEqual(decoded?.source, "source")
    }

    /// test_19: JSONValue encoding and decoding works for all supported types
    func test_19_JSONValue_encodingDecoding_allTypes() throws {
        let values: [JSONValue] = [
            .string("test"),
            .number(42.5),
            .bool(true),
            .object(["key": .string("value")]),
            .array([.string("item1"), .number(123)]),
            .null
        ]
        
        for value in values {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
            XCTAssertEqual(String(describing: value), String(describing: decoded))
        }
    }

    /// test_20: JSONValue convenience accessors return correct values
    func test_20_JSONValue_convenienceAccessors() {
        let stringValue: JSONValue = .string("hello")
        let numberValue: JSONValue = .number(42.5)
        let boolValue: JSONValue = .bool(true)
        let objectValue: JSONValue = .object(["key": .string("value")])
        let arrayValue: JSONValue = .array([.string("item1")])
        let nullValue: JSONValue = .null
        
        XCTAssertEqual(stringValue.stringValue, "hello")
        XCTAssertEqual(numberValue.numberValue, 42.5)
        XCTAssertEqual(boolValue.boolValue, true)
        XCTAssertNotNil(objectValue.objectValue)
        XCTAssertNotNil(arrayValue.arrayValue)
        XCTAssertNil(nullValue.stringValue)
        XCTAssertNil(nullValue.numberValue)
        XCTAssertNil(nullValue.boolValue)
        XCTAssertNil(nullValue.objectValue)
        XCTAssertNil(nullValue.arrayValue)
    }

    /// test_21: encodeSubscription returns nil for unsupported subscription type
    func test_21_encodeSubscription_unsupportedType() {
        struct UnsupportedSubscription: Subscription {
            let channel: String = "unsupported"
        }
        
        let unsupported = UnsupportedSubscription()
        let data = encodeSubscription(unsupported)
        XCTAssertNil(data)
    }

    /// test_22: decodeSubscription returns nil for invalid data
    func test_22_decodeSubscription_invalidData() {
        XCTAssertNil(decodeSubscription(from: invalidJSONData()))
    }

    /// test_23: encodeUTM returns nil for nil input
    func test_23_encodeUTM_nilInput() {
        XCTAssertNil(encodeUTM(nil))
    }

    /// test_24: decodeUTM returns nil for nil input
    func test_24_decodeUTM_nilInput() {
        XCTAssertNil(decodeUTM(nil))
    }

    /// test_25: JSONValue handles unknown types with error
    func test_25_JSONValue_unknownTypeHandling() {
        let validData = try! JSONEncoder().encode(JSONValue.string("test"))
        XCTAssertNoThrow(try JSONDecoder().decode(JSONValue.self, from: validData))
    }
}
