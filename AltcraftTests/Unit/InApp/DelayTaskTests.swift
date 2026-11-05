//
//  DelayTaskTests.swift
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
 * DelayTaskTests
 *
 * Positive scenarios:
 * - test_1: getTriggerDelay returns delay for matching trigger.
 * - test_2: getTriggerDelay returns 0 when no trigger matches.
 * - test_3: getTriggerDelay returns 0 when triggerEvents is empty.
 * - test_4: resetTriggerDelay creates copy with delay reset to 0.
 * - test_5: resetTriggerDelay preserves non-matched trigger delays.
 * - test_6: resetTriggerDelay preserves all other InApp fields.
 * - test_7: getTriggerDelay matches by both name and type.
 *
 * Edge scenarios:
 * - test_8: getTriggerDelay handles case-insensitive type comparison.
 * - test_9: resetTriggerDelay with no matching trigger leaves all delays unchanged.
 *
 */
@available(iOSApplicationExtension, unavailable)
final class DelayTaskTests: IsolatedTestCase {

    private func makeInApp(
        triggerEvents: [InAppModel.TriggerEvent] = [],
        actionTriggerName: String = "myTrigger",
        actionTriggerType: InAppModel.TriggerType = .custom
    ) -> InAppModel.InApp {
        InAppModel.InApp(
            uid: "uid-1",
            companyId: 1,
            smid: "smid-1",
            type: "custom",
            contentUrl: "https://example.com",
            checksum: "chk",
            options: InAppModel.PlacementOptions(
                endTime: 0,
                triggerEvents: triggerEvents
            ),
            deadline: 0,
            isTest: false,
            lastCompanyUpdate: 1000,
            actionTriggerName: actionTriggerName,
            actionTriggerType: actionTriggerType
        )
    }

    private func makeTrigger(
        for inApp: InAppModel.InApp
    ) -> InAppModel.InAppTrigger {
        InAppModel.InAppTrigger(
            name: inApp.actionTriggerName,
            type: inApp.actionTriggerType
        )
    }

    /// test_1: getTriggerDelay returns delay for matching trigger
    func test_1_getTriggerDelay_returns_delay_for_matching_trigger() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "myTrigger",
                delay: 30
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        XCTAssertEqual(
            DelayTask.getTriggerDelay(inApp),
            30
        )
    }

    /// test_2: getTriggerDelay returns 0 when no trigger matches
    func test_2_getTriggerDelay_returns_zero_when_no_trigger_matches() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "otherTrigger",
                delay: 30
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        XCTAssertEqual(
            DelayTask.getTriggerDelay(inApp),
            0
        )
    }

    /// test_3: getTriggerDelay returns 0 when triggerEvents is empty
    func test_3_getTriggerDelay_returns_zero_when_trigger_events_is_empty() {
        let inApp = makeInApp(
            triggerEvents: []
        )

        XCTAssertEqual(
            DelayTask.getTriggerDelay(inApp),
            0
        )
    }

    /// test_4: resetTriggerDelay creates copy with delay reset to 0
    func test_4_resetTriggerDelay_creates_copy_with_delay_reset_to_zero() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "myTrigger",
                delay: 60
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        let reset = DelayTask.resetTriggerDelay(
            inApp,
            trigger: makeTrigger(for: inApp)
        )

        XCTAssertEqual(
            reset.options.triggerEvents.count,
            1
        )
        XCTAssertEqual(
            reset.options.triggerEvents.first?.name,
            "myTrigger"
        )
        XCTAssertEqual(
            reset.options.triggerEvents.first?.delay,
            0
        )
    }

    /// test_5: resetTriggerDelay preserves non-matched trigger delays
    func test_5_resetTriggerDelay_preserves_non_matched_trigger_delays() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "myTrigger",
                delay: 60
            ),
            InAppModel.TriggerEvent(
                type: "default",
                name: "openApp",
                delay: 10
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        let reset = DelayTask.resetTriggerDelay(
            inApp,
            trigger: makeTrigger(for: inApp)
        )

        let matched = reset.options.triggerEvents.first {
            $0.name == "myTrigger"
        }

        let unmatched = reset.options.triggerEvents.first {
            $0.name == "openApp"
        }

        XCTAssertEqual(
            matched?.delay,
            0
        )
        XCTAssertEqual(
            unmatched?.delay,
            10
        )
    }

    /// test_6: resetTriggerDelay preserves all other InApp fields
    func test_6_resetTriggerDelay_preserves_all_other_inapp_fields() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "myTrigger",
                delay: 60
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        let reset = DelayTask.resetTriggerDelay(
            inApp,
            trigger: makeTrigger(for: inApp)
        )

        XCTAssertEqual(reset.uid, inApp.uid)
        XCTAssertEqual(reset.companyId, inApp.companyId)
        XCTAssertEqual(reset.smid, inApp.smid)
        XCTAssertEqual(reset.type, inApp.type)
        XCTAssertEqual(reset.contentUrl, inApp.contentUrl)
        XCTAssertEqual(reset.checksum, inApp.checksum)
        XCTAssertEqual(reset.deadline, inApp.deadline)
        XCTAssertEqual(reset.isTest, inApp.isTest)
        XCTAssertEqual(reset.lastCompanyUpdate, inApp.lastCompanyUpdate)
        XCTAssertEqual(reset.actionTriggerName, inApp.actionTriggerName)
        XCTAssertEqual(reset.actionTriggerType, inApp.actionTriggerType)

        XCTAssertEqual(reset.options.endTime, inApp.options.endTime)
        XCTAssertEqual(reset.options.isAnonim, inApp.options.isAnonim)
        XCTAssertEqual(reset.options.placements, inApp.options.placements)
        XCTAssertEqual(reset.options.appVersions, inApp.options.appVersions)
        XCTAssertEqual(
            reset.options.appVersionConditionRaw,
            inApp.options.appVersionConditionRaw
        )
        XCTAssertEqual(reset.options.priority, inApp.options.priority)
        XCTAssertEqual(
            reset.options.impressionsLimit,
            inApp.options.impressionsLimit
        )
    }

    /// test_7: getTriggerDelay matches by both name and type
    func test_7_getTriggerDelay_matches_by_both_name_and_type() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "myTrigger",
                delay: 30
            ),
            InAppModel.TriggerEvent(
                type: "default",
                name: "myTrigger",
                delay: 50
            )
        ]

        let customInApp = makeInApp(
            triggerEvents: triggers,
            actionTriggerType: .custom
        )

        let defaultInApp = makeInApp(
            triggerEvents: triggers,
            actionTriggerType: .default
        )

        XCTAssertEqual(
            DelayTask.getTriggerDelay(customInApp),
            30
        )
        XCTAssertEqual(
            DelayTask.getTriggerDelay(defaultInApp),
            50
        )
    }

    /// test_8: getTriggerDelay handles case-insensitive type comparison
    func test_8_getTriggerDelay_handles_case_insensitive_type_comparison() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "CUSTOM",
                name: "myTrigger",
                delay: 42
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers
        )

        XCTAssertEqual(
            DelayTask.getTriggerDelay(inApp),
            42
        )
    }

    /// test_9: resetTriggerDelay with no matching trigger leaves all delays unchanged
    func test_9_resetTriggerDelay_with_no_matching_trigger_leaves_all_delays_unchanged() {
        let triggers = [
            InAppModel.TriggerEvent(
                type: "custom",
                name: "other",
                delay: 20
            )
        ]

        let inApp = makeInApp(
            triggerEvents: triggers,
            actionTriggerName: "myTrigger"
        )

        let reset = DelayTask.resetTriggerDelay(
            inApp,
            trigger: makeTrigger(for: inApp)
        )

        XCTAssertEqual(
            reset.options.triggerEvents.first?.delay,
            20
        )
    }
}
