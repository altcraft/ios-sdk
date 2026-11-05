//
//  AltcraftConfigurationTests.swift
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
 * AltcraftConfigurationTest
 *
 * Positive scenarios:
 *  - test_1: build succeeds with minimal required values (apiUrl only).
 *  - test_2: build succeeds with all optional fields provided.
 *  - test_3: getters return the same values that were set via the builder.
 *  - test_7: module configurations round-trip through the builder.
 *
 * Negative scenarios:
 *  - test_4: build with an empty apiUrl produces an invalid configuration.
 *  - test_5: build with a blank apiUrl produces an invalid configuration.
 *  - test_6: build with a blank rToken produces an invalid configuration.
 */
final class AltcraftConfigurationTest: IsolatedTestCase {

    private let apiUrl       = "https://api.altcraft.example"
    private let emptyApiUrl  = ""
    private let blankApiUrl  = "   "
    private let blankRToken  = "   "
    private let rToken       = "r-token-123"

    private let appInfo = AppInfo(appID: "com.altcraft.demo",
                                  appIID: "iid-001",
                                  appVer: "1.0.0")

    private func makeBuilder(apiUrl: String) -> AltcraftConfiguration.Builder {
        AltcraftConfiguration.Builder(apiUrl: apiUrl)
    }

    /// test_1: build succeeds with minimal required values (apiUrl only)
    func test_1_build_succeeds_withMinimalRequiredValues() {
        let config = makeBuilder(apiUrl: apiUrl)
            .build()

        XCTAssertEqual(config.getApiUrl(), apiUrl)
        XCTAssertNil(config.getRToken())
        XCTAssertNil(config.getAppInfo())
        XCTAssertTrue(config.valid)
    }

    /// test_2: build succeeds with all optional fields provided
    func test_2_build_succeeds_withAllFields() {
        let config = AltcraftConfiguration.Builder(
            apiUrl: apiUrl,
            rToken: rToken,
            appInfo: appInfo
        )
        .build()

        XCTAssertEqual(config.getApiUrl(), apiUrl)
        XCTAssertEqual(config.getRToken(), rToken)
        XCTAssertEqual(config.getAppInfo()?.appID, appInfo.appID)
        XCTAssertEqual(config.getAppInfo()?.appIID, appInfo.appIID)
        XCTAssertEqual(config.getAppInfo()?.appVer, appInfo.appVer)
        XCTAssertTrue(config.valid)
    }

    /// test_3: getters return the same values that were set
    func test_3_getters_returnExpectedValues() {
        let config = AltcraftConfiguration.Builder(
            apiUrl: apiUrl,
            rToken: rToken,
            appInfo: appInfo
        )
        .build()

        XCTAssertEqual(config.getApiUrl(), apiUrl)
        XCTAssertEqual(config.getRToken(), rToken)
        XCTAssertEqual(config.getAppInfo()?.appID, appInfo.appID)
        XCTAssertEqual(config.getAppInfo()?.appIID, appInfo.appIID)
        XCTAssertEqual(config.getAppInfo()?.appVer, appInfo.appVer)
    }

    /// test_4: build with an empty apiUrl produces an invalid configuration
    func test_4_build_withEmptyApiUrl_isInvalid() {
        let config = AltcraftConfiguration.Builder(apiUrl: emptyApiUrl)
            .build()

        XCTAssertTrue(config.apiUrlIsBlank)
        XCTAssertFalse(config.valid)
    }

    /// test_5: build with a blank apiUrl produces an invalid configuration
    func test_5_build_withBlankApiUrl_isInvalid() {
        let config = AltcraftConfiguration.Builder(apiUrl: blankApiUrl)
            .build()

        XCTAssertTrue(config.apiUrlIsBlank)
        XCTAssertFalse(config.valid)
    }

    /// test_6: build with a blank rToken produces an invalid configuration
    func test_6_build_withBlankRToken_isInvalid() {
        let config = AltcraftConfiguration.Builder(
            apiUrl: apiUrl,
            rToken: blankRToken
        )
        .build()

        XCTAssertTrue(config.rTokenIsBlank)
        XCTAssertFalse(config.valid)
    }

    /// test_7: build stores and returns module configurations by identifier.
    func test_7_add_module_configurations_round_trip() {
        let config = makeBuilder(apiUrl: apiUrl)
            .addModuleConfiguration(DummyConfig(moduleId: "altcraft-push"))
            .addModuleConfiguration(DummyConfig(moduleId: "altcraft-inapp"))
            .build()

        XCTAssertNotNil(config.getModuleConfigurations()["altcraft-push"])
        XCTAssertNotNil(config.getModuleConfigurations()["altcraft-inapp"])
        XCTAssertNil(config.getModuleConfigurations()["altcraft-unknown"])
    }
}

/// Test module configuration for the core module configuration contract.
private struct DummyConfig: ModuleConfiguration {
    let moduleId: String
}
