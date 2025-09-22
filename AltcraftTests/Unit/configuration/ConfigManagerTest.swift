//
//  ConfigCoordinatorTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ConfigCoordinatorTest
 *
 * Positive scenarios:
 *  - test_1: saveConfig returns true for valid configuration (fast path).
 *  - test_2: save then load returns the freshly saved configuration.
 *  - test_3: two consecutive saveConfig calls are serialized (order preserved).
 *
 * Negative scenarios:
 *  - test_4: saveConfig with nil configuration calls completion(false) and does not crash.
 *
 * Notes:
 *  - We do NOT try to stub top-level functions. That is not feasible across modules without
 *    adding seams to production code. Here we rely on the real implementations.
 *  - The 5s watchdog + background branch is intentionally NOT covered by unit test to avoid
 *    slow/flaky runs. Cover it via UI/integration test (background → foreground transition).
 */

final class ConfigCoordinatorTest: XCTestCase {

    // Shared sample data
    private let apiUrl = "https://api.altcraft.example"
    private let rToken = "r-token-xyz"
    private let appInfo = AppInfo(appID: "com.altcraft.demo", appIID: "iid-777", appVer: "1.2.3")
    private let providers = [
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase,
        Constants.ProviderName.huawei
    ]

    // MARK: - Helpers

    private func makeConfig() -> AltcraftConfiguration {
        let cfg = AltcraftConfiguration.Builder()
            .setApiUrl(apiUrl)
            .setRToken(rToken)
            .setAppInfo(appInfo)
            .setProviderPriorityList(providers)
            .build()
        precondition(cfg != nil, "Builder should produce a non-nil config for valid inputs")
        return cfg!
    }

    // MARK: - Tests

    /// test_1: saveConfig returns true for valid configuration (fast path).
    func test_1_saveConfig_success_returnsTrue() {
        let cfg = makeConfig()

        let exp = expectation(description: "save completion")
        var result: Bool?
        ConfigCoordinator.shared.saveConfig(configuration: cfg) { ok in
            result = ok
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        XCTAssertEqual(result, true, "saveConfig should succeed for a valid configuration")
    }

    /// test_2: save then load returns the freshly saved configuration.
    func test_2_saveThenLoad_roundtripReturnsFreshConfig() {
        let cfg = makeConfig()

        let saveExp = expectation(description: "save done")
        ConfigCoordinator.shared.saveConfig(configuration: cfg) { ok in
            XCTAssertTrue(ok)
            saveExp.fulfill()
        }
        wait(for: [saveExp], timeout: 3.0)

        let loadExp = expectation(description: "load done")
        var loaded: Configuration?
        getConfig { conf in
            loaded = conf
            loadExp.fulfill()
        }
        wait(for: [loadExp], timeout: 3.0)

        XCTAssertNotNil(loaded, "Loaded configuration must not be nil after a successful save")
        XCTAssertEqual(loaded?.url, apiUrl)
        XCTAssertEqual(loaded?.rToken, rToken)
        XCTAssertEqual(loaded?.appInfo?.appID, appInfo.appID)
        XCTAssertEqual(loaded?.appInfo?.appIID, appInfo.appIID)
        XCTAssertEqual(loaded?.appInfo?.appVer, appInfo.appVer)
        XCTAssertEqual(loaded?.providerPriorityList ?? [], providers)
    }

    /// test_3: two consecutive saveConfig calls are serialized in order.
    func test_3_twoSaves_areSerializedInOrder() {
        let cfg1 = AltcraftConfiguration.Builder().setApiUrl("https://api.altcraft.example/one").build()
        let cfg2 = AltcraftConfiguration.Builder().setApiUrl("https://api.altcraft.example/two").build()
        XCTAssertNotNil(cfg1); XCTAssertNotNil(cfg2)

        let done1 = expectation(description: "save1")
        let done2 = expectation(description: "save2")

        // Kick both saves quickly; implementation uses a serial queue internally.
        ConfigCoordinator.shared.saveConfig(configuration: cfg1!) { ok in
            XCTAssertTrue(ok)
            done1.fulfill()
        }
        ConfigCoordinator.shared.saveConfig(configuration: cfg2!) { ok in
            XCTAssertTrue(ok)
            done2.fulfill()
        }

        wait(for: [done1, done2], timeout: 5.0)

        // Sanity: latest load should reflect the second save (the last write wins)
        let loadExp = expectation(description: "load after two saves")
        var loaded: Configuration?
        getConfig { conf in loaded = conf; loadExp.fulfill() }
        wait(for: [loadExp], timeout: 3.0)
        XCTAssertEqual(loaded?.url, "https://api.altcraft.example/two")
    }

    /// test_4: saveConfig with nil configuration returns false immediately.
    func test_4_saveConfig_nil_returnsFalse() {
        let exp = expectation(description: "completion")
        var result: Bool?
        ConfigCoordinator.shared.saveConfig(configuration: nil) { ok in
            result = ok
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(result, false)
    }
}

