//
//  InAppVariablesTests.swift
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
 * InAppVariablesTests
 *
 * Positive scenarios:
 *  - test_1: getCurrentPlacement returns nil by default.
 *  - test_2: setCurrentPlacement updates placement value.
 *  - test_3: getOpenBySession returns 0 by default.
 *  - test_4: openBySessionInc increments session counter.
 *  - test_5: getTriggerCount returns 0 for unknown trigger.
 *  - test_6: triggerBySessionInc increments correct counter map.
 *  - test_7: reset clears session counters and preserves the current screen.
 *  - test_8: default and custom trigger counters are independent.
 *
 * Edge scenarios:
 *  - test_9: setCurrentPlacement with same value does not change state.
 *  - test_10: setCurrentPlacement nil then value works correctly.
 */
final class InAppVariablesTests: IsolatedTestCase {

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

    /// test_1: getCurrentPlacement returns nil by default
    func test_1_getCurrentPlacement_returnsNilByDefault() {
        XCTAssertNil(InAppVariables.shared.getCurrentPlacement())
    }

    /// test_2: setCurrentPlacement updates placement value
    func test_2_setCurrentPlacement_updatesValue() {
        InAppVariables.shared.setCurrentScreen("home")
        XCTAssertEqual(InAppVariables.shared.getCurrentPlacement(), "home")
    }

    /// test_3: getOpenBySession returns 0 by default
    func test_3_getOpenBySession_returnsZeroByDefault() {
        XCTAssertEqual(InAppVariables.shared.getOpenBySession(), 0)
    }

    /// test_4: openBySessionInc increments session counter
    func test_4_openBySessionInc_incrementsCounter() {
        XCTAssertEqual(InAppVariables.shared.getOpenBySession(), 0)
        InAppVariables.shared.openBySessionInc()
        XCTAssertEqual(InAppVariables.shared.getOpenBySession(), 1)
        InAppVariables.shared.openBySessionInc()
        XCTAssertEqual(InAppVariables.shared.getOpenBySession(), 2)
    }

    /// test_5: getTriggerCount returns 0 for unknown trigger
    func test_5_getTriggerCount_returnsZero_forUnknownTrigger() {
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.custom, "unknown"), 0)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.default, "unknown"), 0)
    }

    /// test_6: triggerBySessionInc increments correct counter map
    func test_6_triggerBySessionInc_incrementsCorrectMap() {
        let customInApp = InAppModel.InApp(
            uid: "1", companyId: 1, smid: "s1", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(endTime: 0),
            deadline: 0, isTest: false, lastCompanyUpdate: 0,
            actionTriggerName: "myTrigger", actionTriggerType: .custom
        )
        let defaultInApp = InAppModel.InApp(
            uid: "2", companyId: 2, smid: "s2", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(endTime: 0),
            deadline: 0, isTest: false, lastCompanyUpdate: 0,
            actionTriggerName: "openApp", actionTriggerType: .default
        )

        InAppVariables.shared.triggerBySessionInc(customInApp)
        InAppVariables.shared.triggerBySessionInc(defaultInApp)
        InAppVariables.shared.triggerBySessionInc(customInApp)

        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.custom, "myTrigger"), 2)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.default, "openApp"), 1)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.custom, "openApp"), 0)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.default, "myTrigger"), 0)
    }

    /// test_7: reset clears session counters and preserves the current screen
    ///
    /// Android parity (`InAppVariables.reset`): the current screen is owned
    /// by the application and survives resets.
    func test_7_reset_clearsCounters_preservesScreen() {
        InAppVariables.shared.setCurrentScreen("home")
        InAppVariables.shared.openBySessionInc()

        let inApp = InAppModel.InApp(
            uid: "1", companyId: 1, smid: "s1", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(endTime: 0),
            deadline: 0, isTest: false, lastCompanyUpdate: 0,
            actionTriggerName: "t", actionTriggerType: .custom
        )
        InAppVariables.shared.triggerBySessionInc(inApp)

        InAppVariables.shared.reset()

        XCTAssertEqual(
            InAppVariables.shared.getCurrentPlacement(),
            "home",
            "The current screen must survive a reset"
        )
        XCTAssertEqual(InAppVariables.shared.getOpenBySession(), 0)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.custom, "t"), 0)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.default, "t"), 0)
    }

    /// test_8: default and custom trigger counters are independent
    func test_8_defaultAndCustomTriggers_areIndependent() {
        let inApp = InAppModel.InApp(
            uid: "1", companyId: 1, smid: "s1", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(endTime: 0),
            deadline: 0, isTest: false, lastCompanyUpdate: 0,
            actionTriggerName: "sameName", actionTriggerType: .custom
        )
        let inApp2 = InAppModel.InApp(
            uid: "2", companyId: 2, smid: "s2", type: "custom",
            contentUrl: "http://x", checksum: "",
            options: InAppModel.PlacementOptions(endTime: 0),
            deadline: 0, isTest: false, lastCompanyUpdate: 0,
            actionTriggerName: "sameName", actionTriggerType: .default
        )

        InAppVariables.shared.triggerBySessionInc(inApp)
        InAppVariables.shared.triggerBySessionInc(inApp2)

        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.custom, "sameName"), 1)
        XCTAssertEqual(InAppVariables.shared.getTriggerCount(.default, "sameName"), 1)
    }

    /// test_9: setCurrentPlacement with same value does not change state
    func test_9_setCurrentPlacement_sameValueNoChange() {
        InAppVariables.shared.setCurrentScreen("home")
        InAppVariables.shared.setCurrentScreen("home")
        XCTAssertEqual(InAppVariables.shared.getCurrentPlacement(), "home")
    }

    /// test_10: setCurrentPlacement nil then value works correctly
    func test_10_setCurrentPlacement_nilThenValue() {
        InAppVariables.shared.setCurrentScreen(nil)
        XCTAssertNil(InAppVariables.shared.getCurrentPlacement())
        InAppVariables.shared.setCurrentScreen("settings")
        XCTAssertEqual(InAppVariables.shared.getCurrentPlacement(), "settings")
    }
}
