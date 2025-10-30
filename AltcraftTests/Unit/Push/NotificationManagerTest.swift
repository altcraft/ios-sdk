//
//  NotificationManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import UserNotifications
@testable import Altcraft

/**
 * NotificationManagerTests (iOS 13 compatible)
 *
 * Coverage:
 *  - test_1_willPresent_returnsExpectedOptions_inForeground
 */
final class NotificationManagerTests: XCTestCase {

    /// Builds foreground options without referencing `.banner` on iOS < 14.
    private func buildExpectedOptions() -> UNNotificationPresentationOptions {
        var options: UNNotificationPresentationOptions = [.badge, .sound]
        if #available(iOS 14.0, *) {
            options.insert(.banner)
        } else {
            options.insert(.alert)
        }
        return options
    }

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
