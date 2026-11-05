//
//  CheckAvailabilityTests.swift
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
 * CheckAvailabilityTests
 *
 * Positive scenarios:
 *  - test_1: Nil availability always allows.
 *  - test_2: Empty availability fields always allows.
 *  - test_3: Year match allows.
 *  - test_4: Month match allows.
 *  - test_5: Mday match allows.
 *  - test_6: Weekday match allows.
 *  - test_7: Time period normal range allows.
 *  - test_8: All restrictions match allows.
 *
 * Edge scenarios:
 *  - test_9: Year mismatch blocks.
 *  - test_10: Month mismatch blocks.
 *  - test_11: Mday mismatch blocks.
 *  - test_12: Weekday mismatch blocks.
 *  - test_13: Time period outside range blocks.
 *  - test_14: Midnight-crossing period allows.
 *  - test_15: Midnight-crossing period outside blocks.
 *  - test_16: From equals to always allows.
 *  - test_17: Weekday mapping Foundation Sunday=1 to SDK=0.
 *  - test_18: Weekday mapping Foundation Monday=2 to SDK=1.
 *  - test_19: Timezone conversion works correctly.
 *  - test_20: First Monday in month allows.
 *  - test_21: Second Monday does not match first Monday order.
 *  - test_22: Last Monday in month allows.
 *  - test_23: Non-last Monday does not match last Monday order.
 *  - test_24: Weekday order zero disables order filter.
 */
@available(iOSApplicationExtension, unavailable)
final class CheckAvailabilityTests: IsolatedTestCase {

    private func makeInApp(
        availability: InAppModel.Availability?
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
                availability: availability
            ),
            deadline: 0,
            isTest: false,
            lastCompanyUpdate: 0
        )
    }

    /// test_1: Nil availability always allows
    func test_1_nilAvailability_alwaysAllows() {
        let inApp = makeInApp(availability: nil)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp))
    }

    /// test_2: Empty availability fields always allows
    func test_2_emptyAvailability_alwaysAllows() {
        let inApp = makeInApp(
            availability: InAppModel.Availability()
        )

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp))
    }

    /// test_3: Year match allows
    func test_3_yearMatch_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            years: [2026],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_4: Month match allows
    func test_4_monthMatch_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            months: [6],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_5: Mday match allows
    func test_5_mdayMatch_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            mdays: [15],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_6: Weekday match allows
    func test_6_weekdayMatch_allows() {
        let mondayMillis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: mondayMillis))
    }

    /// test_7: Time period normal range allows
    func test_7_timePeriodNormalRange_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 9, min: 0),
                    to: InAppModel.TimePoint(hour: 11, min: 0)
                )
            ],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_8: All restrictions match allows
    func test_8_allRestrictionsMatch_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 9, min: 0),
                    to: InAppModel.TimePoint(hour: 11, min: 0)
                )
            ],
            mdays: [15],
            wdays: [1],
            months: [6],
            years: [2026],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_9: Year mismatch blocks
    func test_9_yearMismatch_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            years: [1900],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_10: Month mismatch blocks
    func test_10_monthMismatch_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            months: [1],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_11: Mday mismatch blocks
    func test_11_mdayMismatch_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            mdays: [28],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_12: Weekday mismatch blocks
    func test_12_weekdayMismatch_blocks() {
        let mondayMillis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [2],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: mondayMillis))
    }

    /// test_13: Time period outside range blocks
    func test_13_timePeriodOutside_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 0, min: 0),
                    to: InAppModel.TimePoint(hour: 1, min: 0)
                )
            ],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_14: Midnight-crossing period allows
    func test_14_midnightCrossingPeriod_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 23)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 22, min: 0),
                    to: InAppModel.TimePoint(hour: 2, min: 0)
                )
            ],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_15: Midnight-crossing period outside blocks
    func test_15_midnightCrossingPeriodOutside_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 12)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 22, min: 0),
                    to: InAppModel.TimePoint(hour: 2, min: 0)
                )
            ],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_16: From equals to always allows
    func test_16_fromEqualsTo_alwaysAllows() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 12, min: 0),
                    to: InAppModel.TimePoint(hour: 12, min: 0)
                )
            ],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_17: Weekday mapping Foundation Sunday=1 to SDK=0
    func test_17_weekdayMapping_sundayTo0() {
        let sundayMillis = utcMillis(year: 2023, month: 4, day: 16, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [0],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: sundayMillis))
    }

    /// test_18: Weekday mapping Foundation Monday=2 to SDK=1
    func test_18_weekdayMapping_mondayTo1() {
        let mondayMillis = utcMillis(year: 2023, month: 4, day: 17, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: mondayMillis))
    }

    /// test_19: Timezone conversion works correctly
    func test_19_timezoneConversion() {
        let millis = utcMillis(year: 2026, month: 6, day: 15, hour: 10)

        let availability = InAppModel.Availability(
            periods: [
                InAppModel.TimePeriod(
                    from: InAppModel.TimePoint(hour: 13, min: 0),
                    to: InAppModel.TimePoint(hour: 15, min: 0)
                )
            ],
            tz: "Europe/Moscow"
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_20: First Monday in month allows
    func test_20_firstMondayInMonth_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 1, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC",
            wdayOrders: [1]
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_21: Second Monday does not match first Monday order
    func test_21_secondMondayDoesNotMatchFirstOrder_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 8, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC", wdayOrders: [1]
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_22: Last Monday in month allows
    func test_22_lastMondayInMonth_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 29, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC",
            wdayOrders: [-1]
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_23: Non-last Monday does not match last Monday order
    func test_23_nonLastMondayDoesNotMatchLastOrder_blocks() {
        let millis = utcMillis(year: 2026, month: 6, day: 22, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC",
            wdayOrders: [-1]
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertFalse(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    /// test_24: Weekday order zero disables order filter
    func test_24_weekdayOrderZero_allows() {
        let millis = utcMillis(year: 2026, month: 6, day: 8, hour: 10)

        let availability = InAppModel.Availability(
            wdays: [1],
            tz: "UTC",
            wdayOrders: [0]
        )

        let inApp = makeInApp(availability: availability)

        XCTAssertTrue(Check.Availability.canShow(inApp: inApp, nowMillis: millis))
    }

    private func utcMillis(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0
    ) -> Int64 {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current

        let components = DateComponents(
            timeZone: TimeZone(identifier: "UTC"),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )

        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date")
            return 0
        }

        return Int64(date.timeIntervalSince1970 * 1000)
    }
}
