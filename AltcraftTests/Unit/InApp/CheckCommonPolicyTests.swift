//
//  CheckCommonPolicyTests.swift
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
* CheckCommonPolicyTests
*
* Positive scenarios:
* - test_1: Nil policy always allows display.
* - test_2: Zero trigger limit always allows.
* - test_3: Trigger limit not exceeded allows display.
* - test_4: Zero session limit always allows.
* - test_5: Session limit not exceeded allows display.
* - test_6: Zero minInterval always allows.
* - test_7: MinInterval passed allows display.
* - test_8: All limits zero allows display.
*
* Edge scenarios:
* - test_9: Trigger limit exceeded blocks display.
* - test_10: Session limit exceeded blocks display.
* - test_11: MinInterval not passed blocks display.
* - test_12: Any one limit exceeded blocks display.
*
*/
final class CheckCommonPolicyTests: IsolatedTestCase {

    override func setUp() async throws {
        try await super.setUp()
        InAppVariables.shared.reset()
    }

    override func tearDown() {
        InAppVariables.shared.reset()
        super.tearDown()
    }

    private func makeInApp(
        policy: InAppModel.Policy? = nil,
        actionTriggerName: String = "t",
        actionTriggerType: InAppModel.TriggerType = .custom
    ) -> InAppModel.InApp {
        InAppModel.InApp(
            uid: "1",
            companyId: 1,
            smid: "s1",
            type: "custom",
            contentUrl: "http://x",
            checksum: "",
            options: InAppModel.PlacementOptions(
                endTime: 0,
                policy: policy
            ),
            deadline: 0,
            isTest: false,
            lastCompanyUpdate: 0,
            actionTriggerName: actionTriggerName,
            actionTriggerType: actionTriggerType
        )
    }

    /// test_1: Nil policy always allows display
    func test_1_nilPolicy_alwaysAllows() {
        let inApp = makeInApp(policy: nil)

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_2: Zero trigger limit always allows
    func test_2_zeroTriggerLimit_alwaysAllows() {
        InAppVariables.shared.triggerBySessionInc(
            makeInApp(
                policy: InAppModel.Policy(limitByTrigger: 0),
                actionTriggerType: .custom
            )
        )

        InAppVariables.shared.triggerBySessionInc(
            makeInApp(
                policy: InAppModel.Policy(limitByTrigger: 0),
                actionTriggerType: .custom
            )
        )

        let inApp = makeInApp(
            policy: InAppModel.Policy(limitByTrigger: 0)
        )

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_3: Trigger limit not exceeded allows display
    func test_3_triggerLimitNotExceeded_allows() {
        let inApp = makeInApp(
            policy: InAppModel.Policy(limitByTrigger: 3)
        )

        InAppVariables.shared.triggerBySessionInc(inApp)
        InAppVariables.shared.triggerBySessionInc(inApp)

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_4: Zero session limit always allows
    func test_4_zeroSessionLimit_alwaysAllows() {
        InAppVariables.shared.openBySessionInc()
        InAppVariables.shared.openBySessionInc()

        let inApp = makeInApp(
            policy: InAppModel.Policy(limitBySession: 0)
        )

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_5: Session limit not exceeded allows display
    func test_5_sessionLimitNotExceeded_allows() {
        let inApp = makeInApp(
            policy: InAppModel.Policy(limitBySession: 3)
        )

        InAppVariables.shared.openBySessionInc()
        InAppVariables.shared.openBySessionInc()

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_6: Zero minInterval always allows
    func test_6_zeroMinInterval_alwaysAllows() async {
        await InAppStoredVariables.shared.setInAppLastOpenTime()

        let inApp = makeInApp(
            policy: InAppModel.Policy(minIntervalSec: 0)
        )

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_7: MinInterval passed allows display
    func test_7_minIntervalPassed_allows() {
        let oldTime = Int64(Date().timeIntervalSince1970 * 1000) - 100_000
        defaults.set(oldTime, forKey: "ac_last_inapp_open_time")

        let inApp = makeInApp(
            policy: InAppModel.Policy(minIntervalSec: 5)
        )

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_8: All limits zero allows display
    func test_8_allLimitsZero_allows() {
        let inApp = makeInApp(
            policy: InAppModel.Policy()
        )

        XCTAssertTrue(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_9: Trigger limit exceeded blocks display
    func test_9_triggerLimitExceeded_blocks() {
        let inApp = makeInApp(
            policy: InAppModel.Policy(limitByTrigger: 2)
        )

        InAppVariables.shared.triggerBySessionInc(inApp)
        InAppVariables.shared.triggerBySessionInc(inApp)

        XCTAssertFalse(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_10: Session limit exceeded blocks display
    func test_10_sessionLimitExceeded_blocks() {
        let inApp = makeInApp(
            policy: InAppModel.Policy(limitBySession: 2)
        )

        InAppVariables.shared.openBySessionInc()
        InAppVariables.shared.openBySessionInc()

        XCTAssertFalse(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_11: MinInterval not passed blocks display
    func test_11_minIntervalNotPassed_blocks() async {
        await InAppStoredVariables.shared.setInAppLastOpenTime()

        let inApp = makeInApp(
            policy: InAppModel.Policy(minIntervalSec: 3600)
        )

        XCTAssertFalse(Check.CommonPolicy.canShow(inApp: inApp))
    }

    /// test_12: Any one limit exceeded blocks display
    func test_12_anyLimitExceeded_blocks() {
        let inApp = makeInApp(
            policy: InAppModel.Policy(
                limitBySession: 1,
                limitByTrigger: 100,
                minIntervalSec: 0
            )
        )

        InAppVariables.shared.openBySessionInc()

        XCTAssertFalse(Check.CommonPolicy.canShow(inApp: inApp))
    }
}
