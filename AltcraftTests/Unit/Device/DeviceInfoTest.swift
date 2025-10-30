//
//  DeviceInfoNoSeamsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * DeviceInfoNoSeamsTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_deviceIdentifier_returnsSaneNonEmptyToken
 *  - test_2_getDeviceFields_containsRequiredKeys_andTypes
 *  - test_3_getDeviceFields_adTrackingConsistency
 */
final class DeviceInfoNoSeamsTests: XCTestCase {

    private static let expectedOS = "IOS"
    private static let expectedDeviceType = "Mobile"

    private static let msgAdIdAbsent = "_ad_id must be absent when _ad_track == false"
    private static let msgAdIdPresent = "_ad_id must be present when _ad_track == true"
    private static let msgUUIDExpected = "Expected UUID-like string for _ad_id"

    private static let tzPattern = #"^[\+\-][0-9]{4}$"#
    private static let uuidPattern = #"^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$"#

    private static let tzRegex = try! NSRegularExpression(pattern: tzPattern)
    private static let uuidRegex = try! NSRegularExpression(pattern: uuidPattern)

    private var originalDefaultTZ: TimeZone!

    override func setUp() {
        super.setUp()
        originalDefaultTZ = NSTimeZone.default as TimeZone
    }

    override func tearDown() {
        NSTimeZone.default = originalDefaultTZ
        super.tearDown()
    }
    
    // Verifies that deviceIdentifier() returns a non-empty, ASCII-safe string
    func test_1_deviceIdentifier_returnsSaneNonEmptyToken() {
        let ident = DeviceInfo.deviceIdentifier()
        XCTAssertFalse(ident.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Identifier must not be empty")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-,"))
        XCTAssertTrue(ident.unicodeScalars.allSatisfy { allowed.contains($0) }, "Unexpected characters in identifier: \(ident)")
    }

    // Ensures getDeviceFields() includes required keys and valid data types
    func test_2_getDeviceFields_containsRequiredKeys_andTypes() {
        let fields = DeviceInfo.getDeviceFields()
        let requiredKeys: [String] = [
            "_os", "_os_tz", "_ad_track", "_os_language",
            "_device_type", "_device_model", "_device_name", "_os_ver"
        ]
        for key in requiredKeys {
            XCTAssertNotNil(fields[key], "Missing key: \(key)")
        }
        XCTAssertTrue(fields["_os"] is String)
        XCTAssertTrue(fields["_os_tz"] is String)
        XCTAssertTrue(fields["_ad_track"] is Bool)
        XCTAssertTrue(fields["_os_language"] is String)
        XCTAssertTrue(fields["_device_type"] is String)
        XCTAssertTrue(fields["_device_model"] is String)
        XCTAssertTrue(fields["_device_name"] is String)
        XCTAssertTrue(fields["_os_ver"] is String)
        XCTAssertEqual(fields["_os"] as? String, Self.expectedOS)
        XCTAssertEqual(fields["_device_type"] as? String, Self.expectedDeviceType)
        if let tz = fields["_os_tz"] as? String {
            let range = NSRange(location: 0, length: (tz as NSString).length)
            XCTAssertNotNil(Self.tzRegex.firstMatch(in: tz, range: range), "Invalid timezone format: \(tz)")
        }
    }

    // Checks that ad tracking fields (_ad_track and _ad_id) are logically consistent
    func test_3_getDeviceFields_adTrackingConsistency() {
        let fields = DeviceInfo.getDeviceFields()
        guard let track = fields["_ad_track"] as? Bool else {
            return XCTFail("_ad_track must be Bool")
        }
        let adId = fields["_ad_id"] as? String
        if track == false {
            XCTAssertNil(adId, Self.msgAdIdAbsent)
        } else {
            XCTAssertNotNil(adId, Self.msgAdIdPresent)
            if let id = adId {
                let range = NSRange(location: 0, length: (id as NSString).length)
                XCTAssertNotNil(Self.uuidRegex.firstMatch(in: id, range: range), "\(Self.msgUUIDExpected), got: \(id)")
            }
        }
    }
}
