//
//  InAppPlacementCountTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif

/**
 * InAppPlacementCountTests
 *
 * Positive scenarios:
 * - test_1: trimToMax returns input unchanged when count <= max.
 * - test_2: trimToMax keeps the latest (largest companyId) entries.
 * - test_3: trimToMax with max < 1 returns an empty array.
 *
 * Validation scenarios:
 * - test_4: InAppConfiguration valid by default.
 * - test_5: InAppConfiguration invalid when maxPlacements < 1.
 * - test_6: InAppConfiguration invalid when interval <= 0.
 * - test_7: InAppConfiguration Measurement init converts to milliseconds.
 *
 * Persistence scenarios:
 * - test_8: InAppConfigManager round-trips configuration.
 * - test_9: InAppConfigManager flags maxPlacements change on save.
 * - test_10: InAppConfigManager does not flag on first save.
 */
final class InAppPlacementCountTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }
    override class var sdkManagerContainer: NSPersistentContainer? {
        inAppDatabase.persistentContainer
    }

    private func makeInApp(companyId: Int) -> InAppModel.InApp {
        InAppModel.InApp(
            uid: "uid-\(companyId)",
            companyId: companyId,
            smid: "smid-\(companyId)",
            type: "custom",
            contentUrl: "https://example.com/\(companyId)",
            checksum: "chk-\(companyId)",
            options: InAppModel.PlacementOptions(endTime: 5000),
            deadline: 0,
            isTest: false,
            lastCompanyUpdate: 1000
        )
    }

    /// test_1: trimToMax returns input unchanged when count <= max
    func test_1_trimToMax_returnsInput_when_countBelowMax() {
        let items = [makeInApp(companyId: 1), makeInApp(companyId: 2)]

        let result = InAppPlacementCountManager.trimToMax(items, max: 5)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(Set(result.map { $0.companyId }), [1, 2])
    }

    /// test_2: trimToMax keeps the latest (largest companyId) entries
    func test_2_trimToMax_keepsLargestCompanyIds() {
        let items = [
            makeInApp(companyId: 1),
            makeInApp(companyId: 5),
            makeInApp(companyId: 3),
            makeInApp(companyId: 10),
            makeInApp(companyId: 7)
        ]

        let result = InAppPlacementCountManager.trimToMax(items, max: 3)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map { $0.companyId }, [10, 7, 5])
    }

    /// test_3: trimToMax with max < 1 returns an empty array
    func test_3_trimToMax_returnsEmpty_when_maxBelowOne() {
        let items = [makeInApp(companyId: 1), makeInApp(companyId: 2)]

        let result = InAppPlacementCountManager.trimToMax(items, max: 0)

        XCTAssertTrue(result.isEmpty)
    }

    /// test_4: InAppConfiguration valid by default
    func test_4_configuration_validByDefault() {
        let config = InAppConfiguration()

        XCTAssertTrue(config.valid)
        XCTAssertEqual(config.inAppAutoRequest, true)
        XCTAssertEqual(
            config.placementsRequestInterval,
            InAppConstants.PlacementsConfig.requestIntervalMs
        )
        XCTAssertEqual(
            config.maxPlacements,
            InAppConstants.PlacementsConfig.maxPlacements
        )
    }

    /// test_5: InAppConfiguration invalid when maxPlacements < 1
    func test_5_configuration_invalid_when_maxPlacementsBelowOne() {
        let config = InAppConfiguration(maxPlacements: 0)

        XCTAssertFalse(config.valid)
    }

    /// test_6: InAppConfiguration invalid when interval <= 0
    func test_6_configuration_invalid_when_intervalNonPositive() {
        XCTAssertTrue(InAppConfiguration(placementsRequestInterval: -1).valid == false)
        XCTAssertTrue(InAppConfiguration(placementsRequestInterval: 0).valid == false)
    }

    /// test_7: InAppConfiguration Measurement init converts to milliseconds
    func test_7_configuration_measurementInit_convertsToMillis() {
        let config = InAppConfiguration(
            placementsRequestInterval: .init(value: 10, unit: .minutes)
        )

        XCTAssertEqual(config.placementsRequestInterval, 10 * 60 * 1000)
    }

    /// test_8: InAppConfigManager round-trips configuration
    func test_8_configManager_roundTrips_configuration() async {
        let toStore = InAppConfiguration(
            inAppAutoRequest: false,
            placementsRequestInterval: 123_456,
            maxPlacements: 42
        )

        await InAppConfigManager.shared.setConfig(toStore)
        let loaded = await InAppConfigManager.shared.getConfig()

        XCTAssertEqual(loaded.inAppAutoRequest, false)
        XCTAssertEqual(loaded.placementsRequestInterval, 123_456)
        XCTAssertEqual(loaded.maxPlacements, 42)
    }

    /// test_9: InAppConfigManager flags maxPlacements change on save
    func test_9_configManager_flags_maxPlacementsChange() async {
        InAppPlacementCountManager.resetMaxPlacementsChanged()

        await InAppConfigManager.shared.setConfig(
            InAppConfiguration(maxPlacements: 10)
        )
        InAppPlacementCountManager.resetMaxPlacementsChanged()

        await InAppConfigManager.shared.setConfig(
            InAppConfiguration(maxPlacements: 20)
        )

        XCTAssertTrue(InAppPlacementCountManager.isMaxPlacementsChanged())
    }

    /// test_10: InAppConfigManager does not flag on first save
    func test_10_configManager_noFlag_onFirstSave() async {
        InAppPlacementCountManager.resetMaxPlacementsChanged()

        await InAppConfigManager.shared.setConfig(
            InAppConfiguration(maxPlacements: 10)
        )

        XCTAssertFalse(InAppPlacementCountManager.isMaxPlacementsChanged())
    }
}
