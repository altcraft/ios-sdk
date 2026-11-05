//
//  DeviceInfoTests.swift
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

/**
* DeviceInfoNoSeamsTests
*
* Positive scenarios:
* - test_1: deviceIdentifier returns sane non-empty token.
* - test_2: getDeviceFields contains required keys and types.
* - test_3: getDeviceFields contains no advertising keys.
*
*/
final class DeviceInfoNoSeamsTests: XCTestCase {

    private static let expectedOS = "IOS"
    private static let expectedDeviceType = "mob"

    private static let tzPattern = #"^[\+\-][0-9]{4}$"#
    private static let tzRegex: NSRegularExpression = {
        guard let regex = try? NSRegularExpression(pattern: tzPattern) else {
            fatalError("Invalid timezone pattern")
        }
        return regex
    }()

    /// test_1: deviceIdentifier returns sane non-empty token
    func test_1_device_identifier_returns_sane_non_empty_token() {
        let identifier = DeviceInfo.deviceIdentifier()

        XCTAssertFalse(
            identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "Identifier must not be empty"
        )

        let allowedCharacters = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "._-,")
        )

        XCTAssertTrue(
            identifier.unicodeScalars.allSatisfy { allowedCharacters.contains($0) },
            "Unexpected characters in identifier: \(identifier)"
        )
    }

    /// test_2: getDeviceFields contains required keys and types
    func test_2_get_device_fields_contains_required_keys_and_types() async {
        let fields = await MainActor.run {
            DeviceInfo.getDeviceFields().asDictionary()
        }

        let requiredKeys: [String] = [
            "_os",
            "_os_tz",
            "_os_language",
            "_device_type",
            "_device_model",
            "_device_name",
            "_os_ver"
        ]

        for key in requiredKeys {
            XCTAssertNotNil(fields[key], "Missing key: \(key)")
        }

        XCTAssertTrue(fields["_os"] is String)
        XCTAssertTrue(fields["_os_tz"] is String)
        XCTAssertTrue(fields["_os_language"] is String)
        XCTAssertTrue(fields["_device_type"] is String)
        XCTAssertTrue(fields["_device_model"] is String)
        XCTAssertTrue(fields["_device_name"] is String)
        XCTAssertTrue(fields["_os_ver"] is String)

        XCTAssertEqual(fields["_os"] as? String, Self.expectedOS)
        XCTAssertEqual(fields["_device_type"] as? String, Self.expectedDeviceType)

        if let timeZone = fields["_os_tz"] as? String {
            let range = NSRange(location: 0, length: (timeZone as NSString).length)
            XCTAssertNotNil(
                Self.tzRegex.firstMatch(in: timeZone, range: range),
                "Invalid timezone format: \(timeZone)"
            )
        }
    }

    /// test_3: getDeviceFields contains no advertising tracking keys
    func test_3_get_device_fields_has_no_advertising_keys() async {
        let fields = await MainActor.run {
            DeviceInfo.getDeviceFields().asDictionary()
        }

        XCTAssertNil(fields["_ad_track"], "_ad_track must be absent")
        XCTAssertNil(fields["_ad_id"], "_ad_id must be absent")
    }
}
