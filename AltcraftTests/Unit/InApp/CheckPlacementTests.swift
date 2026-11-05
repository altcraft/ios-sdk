//
//  CheckPlacementTests.swift
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
 * CheckPlacementTests
 *
 * Positive scenarios:
 *  - test_1: empty placements always allows.
 *  - test_2: current placement in list allows.
 *  - test_3: no current placement with empty placements allows.
 *
 * Edge scenarios:
 *  - test_4: current placement not in list blocks.
 *  - test_5: no current placement with non-empty placements blocks.
 */
final class CheckPlacementTests: IsolatedTestCase {

    override func setUp() {
        super.setUp()
        // The screen is owned by the application and survives reset();
        // tests clear it explicitly the same way the host app would.
        InAppVariables.shared.setCurrentScreen(nil)
        InAppVariables.shared.reset()
    }

    override func tearDown() {
        InAppVariables.shared.setCurrentScreen(nil)
        InAppVariables.shared.reset()
        super.tearDown()
    }

    private func makeInApp(
        placements: [String]
    ) -> InAppModel.InApp {
        InAppModel.InApp(
            uid: "1", companyId: 1, smid: "s1", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(
                endTime: 0,
                placements: placements
            ),
            deadline: 0, isTest: false, lastCompanyUpdate: 0
        )
    }

    /// test_1: empty placements always allows
    func test_1_emptyPlacements_alwaysAllows() {
        let inApp = makeInApp(placements: [])
        XCTAssertTrue(Check.Placement.canShow(inApp: inApp))
    }

    /// test_2: current placement in list allows
    func test_2_currentPlacementInList_allows() {
        InAppVariables.shared.setCurrentScreen("home")
        let inApp = makeInApp(placements: ["home", "settings"])
        XCTAssertTrue(Check.Placement.canShow(inApp: inApp))
    }

    /// test_3: no current placement with empty placements allows
    func test_3_noCurrentPlacement_emptyPlacements_allows() {
        let inApp = makeInApp(placements: [])
        XCTAssertTrue(Check.Placement.canShow(inApp: inApp))
    }

    /// test_4: current placement not in list blocks
    func test_4_currentPlacementNotInList_blocks() {
        InAppVariables.shared.setCurrentScreen("profile")
        let inApp = makeInApp(placements: ["home", "settings"])
        XCTAssertFalse(Check.Placement.canShow(inApp: inApp))
    }

    /// test_5: no current placement with non-empty placements blocks
    func test_5_noCurrentPlacement_nonEmptyPlacements_blocks() {
        let inApp = makeInApp(placements: ["home"])
        XCTAssertFalse(Check.Placement.canShow(inApp: inApp))
    }
}
