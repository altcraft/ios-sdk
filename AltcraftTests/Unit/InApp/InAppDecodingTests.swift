//
//  InAppDecodingTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif

/**
 * InAppDecodingTests
 *
 * Verifies tolerant JSON decoding of placement models: missing optional
 * keys fall back to default values (Android `kotlinx.serialization`
 * parity) instead of rejecting the whole response.
 *
 * Positive scenarios:
 *  - test_1: PlacementOptions with only end_date decodes with defaults.
 *  - test_2: PlacementOptions null fields fall back to defaults.
 *  - test_3: Policy with missing keys decodes with defaults.
 *  - test_4: LimitByPeriod with missing keys decodes with defaults.
 *  - test_5: TriggerEvent with missing fields decodes with defaults.
 *  - test_6: TimePeriod and TimePoint with missing fields use defaults.
 *  - test_7: Response with stripped placement options decodes fully.
 *
 * Edge scenarios:
 *  - test_8: PlacementOptions without end_date fails (required, Android parity).
 *  - test_9: Trigger event array with partial objects decodes each element.
 *  - test_10: Response with duplicate placement ids → last placement wins
 *             (Android `associateBy` parity), no crash.
 */
final class InAppDecodingTests: IsolatedTestCase {

    // MARK: - Positive scenarios

    func test_1_placementOptions_onlyEndDate_decodesWithDefaults() throws {
        let json = #"{"end_date": 1700000000}"#

        let options = try JSONDecoder().decode(
            InAppModel.PlacementOptions.self, from: Data(json.utf8)
        )

        XCTAssertEqual(options.endTime, 1700000000)
        XCTAssertNil(options.policy)
        XCTAssertFalse(options.isAnonim)
        XCTAssertEqual(options.placements, [])
        XCTAssertEqual(options.appVersions, [])
        XCTAssertNil(options.appVersionConditionRaw)
        XCTAssertEqual(options.priority, 0)
        XCTAssertTrue(options.triggerEvents.isEmpty)
        XCTAssertEqual(options.impressionsLimit, 0)
        XCTAssertNil(options.availability)
    }

    func test_2_placementOptions_nullFields_fallBackToDefaults() throws {
        let json = #"{"end_date": 5, "placements": null, "priority": null, "policy": null}"#

        let options = try JSONDecoder().decode(
            InAppModel.PlacementOptions.self, from: Data(json.utf8)
        )

        XCTAssertEqual(options.endTime, 5)
        XCTAssertNil(options.policy)
        XCTAssertEqual(options.placements, [])
        XCTAssertEqual(options.priority, 0)
    }

    func test_3_policy_missingKeys_decodesWithDefaults() throws {
        let json = #"{}"#

        let policy = try JSONDecoder().decode(
            InAppModel.Policy.self, from: Data(json.utf8)
        )

        XCTAssertEqual(policy.limitBySession, 0)
        XCTAssertEqual(policy.limitByTrigger, 0)
        XCTAssertEqual(policy.limitByPeriod.periodDays, 0)
        XCTAssertEqual(policy.limitByPeriod.limit, 0)
        XCTAssertEqual(policy.minIntervalSec, 0)
    }

    func test_4_limitByPeriod_missingKeys_decodesWithDefaults() throws {
        let json = #"{"limit": 3}"#

        let limit = try JSONDecoder().decode(
            InAppModel.LimitByPeriod.self, from: Data(json.utf8)
        )

        XCTAssertEqual(limit.periodDays, 0)
        XCTAssertEqual(limit.limit, 3)
    }

    func test_5_triggerEvent_missingFields_decodesWithDefaults() throws {
        let json = #"{}"#

        let event = try JSONDecoder().decode(
            InAppModel.TriggerEvent.self, from: Data(json.utf8)
        )

        XCTAssertEqual(event.type, "")
        XCTAssertEqual(event.name, "")
        XCTAssertEqual(event.delay, 0)
    }

    func test_6_timePeriodAndPoint_missingFields_useDefaults() throws {
        let json = #"{}"#

        let period = try JSONDecoder().decode(
            InAppModel.TimePeriod.self, from: Data(json.utf8)
        )
        let point = try JSONDecoder().decode(
            InAppModel.TimePoint.self, from: Data(#"{"hour": 9}"#.utf8)
        )

        XCTAssertEqual(period.from.hour, 0)
        XCTAssertEqual(period.from.min, 0)
        XCTAssertEqual(period.to.hour, 0)
        XCTAssertEqual(period.to.min, 0)
        XCTAssertEqual(point.hour, 9)
        XCTAssertEqual(point.min, 0)
    }

    func test_7_response_strippedOptions_decodesFully() throws {
        let json = """
        {
          "error": 0,
          "error_text": "",
          "last_publish": 100,
          "placement_rules_checksum": "abc",
          "inapps": [
            {
              "id": 42,
              "link": "https://example.com/inapp.html",
              "is_test": false,
              "smid": "smid-1",
              "type": "custom",
              "deadline": 1700000000,
              "last_company_update": 1690000000
            }
          ],
          "placements": [
            {
              "id": 42,
              "checksum": "checksum-1",
              "options": { "end_date": 1800000000 }
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            InAppPlacesResponse.self, from: Data(json.utf8)
        )

        XCTAssertEqual(response.inApps.count, 1)
        let inApp = try XCTUnwrap(response.inApps.first)
        XCTAssertEqual(inApp.companyId, 42)
        XCTAssertEqual(inApp.checksum, "checksum-1")
        XCTAssertEqual(inApp.options.endTime, 1800000000)
        XCTAssertEqual(inApp.options.priority, 0)
        XCTAssertEqual(inApp.options.impressionsLimit, 0)
        XCTAssertTrue(inApp.options.triggerEvents.isEmpty)
        XCTAssertEqual(inApp.actionTriggerName, "")
    }

    // MARK: - Edge scenarios

    func test_8_placementOptions_missingEndDate_throws() {
        let json = #"{"priority": 5}"#

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                InAppModel.PlacementOptions.self, from: Data(json.utf8)
            )
        ) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_9_triggerEventArray_partialObjects_decodesEachElement() throws {
        let json = #"[{}, {"name": "evt", "delay": 10}]"#

        let events = try JSONDecoder().decode(
            [InAppModel.TriggerEvent].self, from: Data(json.utf8)
        )

        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].type, "")
        XCTAssertEqual(events[0].name, "")
        XCTAssertEqual(events[1].name, "evt")
        XCTAssertEqual(events[1].delay, 10)
    }

    /// test_10: response with duplicate placement ids → last placement wins
    /// (Android `associateBy` parity), no crash
    func test_10_response_duplicatePlacementIds_lastWins() throws {
        let json = """
        {
          "error": 0,
          "error_text": "",
          "last_publish": 100,
          "placement_rules_checksum": "abc",
          "inapps": [
            {
              "id": 42,
              "link": "https://example.com/inapp.html",
              "is_test": false,
              "smid": "smid-1",
              "type": "custom",
              "deadline": 1700000000,
              "last_company_update": 1690000000
            }
          ],
          "placements": [
            {
              "id": 42,
              "checksum": "first",
              "options": { "end_date": 1800000000, "priority": 1 }
            },
            {
              "id": 42,
              "checksum": "second",
              "options": { "end_date": 1800000001, "priority": 2 }
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(
            InAppPlacesResponse.self, from: Data(json.utf8)
        )

        XCTAssertEqual(response.inApps.count, 1)
        let inApp = try XCTUnwrap(response.inApps.first)
        XCTAssertEqual(inApp.companyId, 42)
        XCTAssertEqual(inApp.checksum, "second")
        XCTAssertEqual(inApp.options.endTime, 1800000001)
        XCTAssertEqual(inApp.options.priority, 2)
    }
}
