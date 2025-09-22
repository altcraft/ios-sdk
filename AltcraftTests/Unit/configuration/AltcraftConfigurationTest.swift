//
//  AltcraftConfigurationTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * AltcraftConfigurationTest
 *
 * Positive scenarios:
 *  - test_1: build succeeds with minimal required values (apiUrl only).
 *  - test_2: build succeeds with all optional fields provided.
 *  - test_3: getters return the same values that were set via the builder.
 *
 * Negative scenarios:
 *  - test_4: build returns nil when apiUrl is missing.
 *  - test_5: build returns nil when apiUrl is empty.
 *  - test_6: build returns nil when providerPriorityList contains invalid providers.
 *
 * Notes:
 *  - Provider validation uses canonical ids from Constants.ProviderName.*
 */
final class AltcraftConfigurationTest: XCTestCase {

    // ---------- Constants ----------
    private let apiUrl      = "https://api.altcraft.example"
    private let emptyApiUrl = ""
    private let rToken      = "r-token-123"

    // AppInfo matches your struct fields (appID/appIID/appVer)
    private let appInfo = AppInfo(appID: "com.altcraft.demo",
                                  appIID: "iid-001",
                                  appVer: "1.0.0")

    // Canonical provider ids expected by SDK
    private let validProviders: [String] = [
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase,
        Constants.ProviderName.huawei
    ]

    // Intentionally invalid providers for negative test
    private let invalidProviders = ["__UNKNOWN__", "NOT_A_PROVIDER"]

    private func makeBuilder() -> AltcraftConfiguration.Builder {
        AltcraftConfiguration.Builder()
    }

    // ---------------------------
    // Positive
    // ---------------------------

    /// test_1: build succeeds with minimal required values (apiUrl only)
    func test_1_build_succeeds_withMinimalRequiredValues() {
        let config = makeBuilder()
            .setApiUrl(apiUrl)
            .build()

        XCTAssertNotNil(config)
        XCTAssertEqual(config?.getApiUrl(), apiUrl)
        XCTAssertNil(config?.getRToken())
        XCTAssertNil(config?.getAppInfo())
        XCTAssertNil(config?.getProviderPriorityList())
    }

    /// test_2: build succeeds with all optional fields provided
    func test_2_build_succeeds_withAllFields() {
        let config = makeBuilder()
            .setApiUrl(apiUrl)
            .setRToken(rToken)
            .setAppInfo(appInfo)
            .setProviderPriorityList(validProviders)
            .build()

        XCTAssertNotNil(config)
        XCTAssertEqual(config?.getApiUrl(), apiUrl)
        XCTAssertEqual(config?.getRToken(), rToken)
        XCTAssertEqual(config?.getAppInfo()?.appID, appInfo.appID)
        XCTAssertEqual(config?.getAppInfo()?.appIID, appInfo.appIID)
        XCTAssertEqual(config?.getAppInfo()?.appVer, appInfo.appVer)
        XCTAssertEqual(config?.getProviderPriorityList() ?? [], validProviders)
    }

    /// test_3: getters return the same values that were set
    func test_3_getters_returnExpectedValues() {
        let cfg = makeBuilder()
            .setApiUrl(apiUrl)
            .setRToken(rToken)
            .setAppInfo(appInfo)
            .setProviderPriorityList(validProviders)
            .build()

        XCTAssertNotNil(cfg)
        guard let config = cfg else { return }

        XCTAssertEqual(config.getApiUrl(), apiUrl)
        XCTAssertEqual(config.getRToken(), rToken)
        XCTAssertEqual(config.getAppInfo()?.appID, appInfo.appID)
        XCTAssertEqual(config.getAppInfo()?.appIID, appInfo.appIID)
        XCTAssertEqual(config.getAppInfo()?.appVer, appInfo.appVer)
        XCTAssertEqual(config.getProviderPriorityList() ?? [], validProviders)
    }

    // ---------------------------
    // Negative
    // ---------------------------

    /// test_4: build returns nil when apiUrl is missing
    func test_4_build_returnsNil_whenApiUrlMissing() {
        let config = makeBuilder()
            // .setApiUrl(...) intentionally omitted
            .setRToken(rToken)
            .setAppInfo(appInfo)
            .setProviderPriorityList(validProviders)
            .build()

        XCTAssertNil(config)
    }

    /// test_5: build returns nil when apiUrl is empty
    func test_5_build_returnsNil_whenApiUrlEmpty() {
        let config = makeBuilder()
            .setApiUrl(emptyApiUrl)
            .setRToken(rToken)
            .build()

        XCTAssertNil(config)
    }

    /// test_6: build returns nil when providerPriorityList contains invalid providers
    func test_6_build_returnsNil_whenProvidersInvalid() {
        let config = makeBuilder()
            .setApiUrl(apiUrl)
            .setProviderPriorityList(invalidProviders)
            .build()

        XCTAssertNil(config)
    }
}

