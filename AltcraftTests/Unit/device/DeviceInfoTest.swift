//
//  DeviceInfoNoSeamsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * DeviceInfoNoSeamsTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_deviceIdentifier_returnsSaneNonEmptyToken:
 *      ensures DeviceInfo.deviceIdentifier() returns a non-empty token with safe characters.
 *
 *  - test_2_getDeviceFields_containsRequiredKeys_andTypes:
 *      ensures DeviceInfo.getDeviceFields() contains required keys with expected types/values
 *      and the timezone string matches "+/-hhmm".
 *
 *  - test_3_getDeviceFields_adTrackingConsistency:
 *      ensures internal consistency between "_ad_track" and "_ad_id"
 *      (absent when tracking is false; UUID-like when true).
 *
 * Notes:
 *  - Uses production code only, no swizzling or seams.
 *  - Avoids environment-specific exact values.
 */
final class DeviceInfoNoSeamsTests: XCTestCase {

    // MARK: - Constants

    private static let expectedOS = "IOS"
    private static let expectedDeviceType = "Mobile"

    private static let msgAdIdAbsent = "_ad_id must be absent when _ad_track == false"
    private static let msgAdIdPresent = "_ad_id must be present when _ad_track == true"
    private static let msgUUIDExpected = "Expected UUID-like string for _ad_id"

    // Regex patterns
    private static let tzPattern = #"^[\+\-][0-9]{4}$"#
    private static let uuidPattern = #"^[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}$"#

    // Compiled regex
    private static let tzRegex = try! NSRegularExpression(pattern: tzPattern)
    private static let uuidRegex = try! NSRegularExpression(pattern: uuidPattern)

    // MARK: - State

    private var originalDefaultTZ: TimeZone!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        // Save original default time zone to restore later
        originalDefaultTZ = NSTimeZone.default as TimeZone
    }

    override func tearDown() {
        // Restore default time zone to avoid cross-test pollution
        NSTimeZone.default = originalDefaultTZ
        super.tearDown()
    }

    // MARK: - Tests

    func test_1_deviceIdentifier_returnsSaneNonEmptyToken() {
        let ident = DeviceInfo.deviceIdentifier()
        XCTAssertFalse(ident.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Identifier must not be empty")

        // Allowed characters: letters/digits/._-, and comma (e.g., "iPhone14,7")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-,"))
        XCTAssertTrue(ident.unicodeScalars.allSatisfy { allowed.contains($0) }, "Unexpected characters in identifier: \(ident)")
    }

    func test_2_getDeviceFields_containsRequiredKeys_andTypes() {
        let fields = DeviceInfo.getDeviceFields()

        // Required keys presence
        let requiredKeys: [String] = [
            "_os", "_os_tz", "_ad_track", "_os_language",
            "_device_type", "_device_model", "_device_name", "_os_ver"
        ]
        for key in requiredKeys {
            XCTAssertNotNil(fields[key], "Missing key: \(key)")
        }

        // Types
        XCTAssertTrue(fields["_os"] is String)
        XCTAssertTrue(fields["_os_tz"] is String)
        XCTAssertTrue(fields["_ad_track"] is Bool)
        XCTAssertTrue(fields["_os_language"] is String)
        XCTAssertTrue(fields["_device_type"] is String)
        XCTAssertTrue(fields["_device_model"] is String)
        XCTAssertTrue(fields["_device_name"] is String)
        XCTAssertTrue(fields["_os_ver"] is String)

        // Invariants
        XCTAssertEqual(fields["_os"] as? String, Self.expectedOS)
        XCTAssertEqual(fields["_device_type"] as? String, Self.expectedDeviceType)

        // Time zone string format "+/-hhmm"
        if let tz = fields["_os_tz"] as? String {
            XCTAssertNotNil(Self.tzRegex.firstMatch(in: tz, range: NSRange(location: 0, length: tz.count)),
                            "Invalid timezone format: \(tz)")
        }
    }

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
                XCTAssertNotNil(Self.uuidRegex.firstMatch(in: id, range: NSRange(location: 0, length: id.count)),
                                "\(Self.msgUUIDExpected), got: \(id)")
            }
        }
    }
}

