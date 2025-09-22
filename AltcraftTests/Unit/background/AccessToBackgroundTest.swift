//
//  AccessToBackgroundTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * AccessToBackgroundTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_accessToBackground_insertsName_once
 *  - test_2_accessToBackground_isIdempotent_onSecondCall
 *  - test_3_accessToBackground_usesExpectedTaskName
 *
 * Notes:
 *  - We avoid asserting system background task behavior (no swizzling of UIApplication).
 *  - Tests focus on deterministic state: the internal Set that guards re-entrance.
 *  - Calls are performed on the main queue to mirror production usage.
 */
final class AccessToBackgroundTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Ensure clean state for each test
        AccessToBackground.shared.activeBackgroundTasks.removeAll()
    }

    override func tearDown() {
        AccessToBackground.shared.activeBackgroundTasks.removeAll()
        super.tearDown()
    }

    /// First call should insert exactly one name into the active set.
    func test_1_accessToBackground_insertsName_once() {
        let bg = AccessToBackground.shared

        let exp = expectation(description: "main thread call")
        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(bg.activeBackgroundTasks.count, 1, "Exactly one background task name must be tracked")
        XCTAssertTrue(bg.activeBackgroundTasks.contains(bg.name), "Tracked set must contain the configured task name")
    }

    /// Second call while active should be idempotent: no duplicates in the Set.
    func test_2_accessToBackground_isIdempotent_onSecondCall() {
        let bg = AccessToBackground.shared

        let exp = expectation(description: "two main-thread calls")
        exp.expectedFulfillmentCount = 2

        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(bg.activeBackgroundTasks.count, 1, "Repeated calls must not add duplicates")
        XCTAssertTrue(bg.activeBackgroundTasks.contains(bg.name))
    }

    /// Verifies the configured background task name is the one registered in the Set.
    func test_3_accessToBackground_usesExpectedTaskName() {
        let bg = AccessToBackground.shared

        let exp = expectation(description: "call")
        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(bg.activeBackgroundTasks.first, bg.name, "Registered task name should match Constants.bgTaskName")
    }
}

