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
 * AccessToBackgroundTests
 *
 * Positive scenarios:
 *  - test_1: accessToBackground first call → inserts exactly one task name into active set.
 *  - test_2: accessToBackground repeated calls → idempotent, no duplicates in active set.
 *  - test_3: accessToBackground task name → uses expected task name from configuration.
 *
 * Notes:
 *  - Tests background task tracking and idempotent behavior.
 *  - Ensures proper task name registration and duplicate prevention.
 */
final class AccessToBackgroundTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AccessToBackground.shared.activeBackgroundTasks.removeAll()
    }

    override func tearDown() {
        AccessToBackground.shared.activeBackgroundTasks.removeAll()
        super.tearDown()
    }

    func test_1_accessToBackground_insertsName_once() {
        let bg = AccessToBackground.shared

        let exp = expectation(description: "main thread call")
        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(bg.activeBackgroundTasks.count, 1)
        XCTAssertTrue(bg.activeBackgroundTasks.contains(bg.name))
    }

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

        XCTAssertEqual(bg.activeBackgroundTasks.count, 1)
        XCTAssertTrue(bg.activeBackgroundTasks.contains(bg.name))
    }

    func test_3_accessToBackground_usesExpectedTaskName() {
        let bg = AccessToBackground.shared

        let exp = expectation(description: "call")
        DispatchQueue.main.async {
            bg.accessToBackground()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertEqual(bg.activeBackgroundTasks.first, bg.name)
    }
}

