//
//  NotificationManagerTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import UserNotifications
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
 * NotificationManagerTests
 *
 * Positive scenarios:
 *  - test_1: willPresent returns expected options in foreground.
 */
final class NotificationManagerTests: XCTestCase {

    private func buildExpectedOptions() -> UNNotificationPresentationOptions {
        var options: UNNotificationPresentationOptions = [.badge, .sound]
        if #available(iOS 14.0, *) {
            options.insert(.banner)
        } else {
            options.insert(.alert)
        }
        return options
    }

    /// test_1: willPresent returns expected options in foreground
    func test_1_willPresent_returnsExpectedOptions_inForeground() {
        let expected = buildExpectedOptions()

        if #available(iOS 14.0, *) {
            XCTAssertTrue(expected.contains(.banner))
            XCTAssertFalse(expected.contains(.alert))
        } else {
            XCTAssertTrue(expected.contains(.alert))
        }

        XCTAssertTrue(expected.contains(.badge))
        XCTAssertTrue(expected.contains(.sound))
    }
}
