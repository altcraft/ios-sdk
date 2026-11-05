//
//  InAppEventProcessingTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import WebKit
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
 * InAppEventProcessingTests
 *
 * Positive scenarios:
 * - test_1: buildInAppEventData returns original payload for delivery event.
 * - test_2: buildInAppEventData returns original payload for show event.
 * - test_3: buildInAppEventData returns original payload for click event.
 * - test_4: buildInAppEventData returns original payload for close event.
 * - test_5: buildInAppEventData sets code 400 for error event.
 *
 * Edge scenarios:
 * - test_6: buildInAppEventData returns nil for nil payload and non-error event.
 * - test_7: buildInAppEventData returns error payload with code 400 for nil payload.
 *
 */
@available(iOSApplicationExtension, unavailable)
@MainActor
final class InAppEventProcessingTests: IsolatedTestCase {

    private func makePayload(
        href: String? = "https://example.com",
        code: Int? = nil,
        message: String? = "message"
    ) -> RequestModel.InAppEventData {
        RequestModel.InAppEventData(
            href: href,
            code: code,
            message: message
        )
    }

    /// test_1: buildInAppEventData returns original payload for delivery event
    func test_1_buildInAppEventData_returns_original_payload_for_delivery_event() {
        let payload = makePayload()

        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .delivery,
            payload: payload
        )

        XCTAssertEqual(result?.href, payload.href)
        XCTAssertEqual(result?.code, payload.code)
        XCTAssertEqual(result?.message, payload.message)
    }

    /// test_2: buildInAppEventData returns original payload for show event
    func test_2_buildInAppEventData_returns_original_payload_for_show_event() {
        let payload = makePayload()

        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .show,
            payload: payload
        )

        XCTAssertEqual(result?.href, payload.href)
        XCTAssertEqual(result?.code, payload.code)
        XCTAssertEqual(result?.message, payload.message)
    }

    /// test_3: buildInAppEventData returns original payload for click event
    func test_3_buildInAppEventData_returns_original_payload_for_click_event() {
        let payload = makePayload()

        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .click,
            payload: payload
        )

        XCTAssertEqual(result?.href, payload.href)
        XCTAssertEqual(result?.code, payload.code)
        XCTAssertEqual(result?.message, payload.message)
    }

    /// test_4: buildInAppEventData returns original payload for close event
    func test_4_buildInAppEventData_returns_original_payload_for_close_event() {
        let payload = makePayload()

        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .close,
            payload: payload
        )

        XCTAssertEqual(result?.href, payload.href)
        XCTAssertEqual(result?.code, payload.code)
        XCTAssertEqual(result?.message, payload.message)
    }

    /// test_5: buildInAppEventData sets code 400 for error event
    func test_5_buildInAppEventData_sets_code_400_for_error_event() {
        let payload = makePayload(
            href: "https://example.com/error",
            code: 999,
            message: "js error"
        )

        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .error,
            payload: payload
        )

        XCTAssertEqual(result?.href, "https://example.com/error")
        XCTAssertEqual(result?.code, 400)
        XCTAssertEqual(result?.message, "js error")
    }

    /// test_6: buildInAppEventData returns nil for nil payload and non-error event
    func test_6_buildInAppEventData_returns_nil_for_nil_payload_and_non_error_event() {
        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .click,
            payload: nil
        )

        XCTAssertNil(result)
    }

    /// test_7: buildInAppEventData returns error payload with code 400 for nil payload
    func test_7_buildInAppEventData_returns_error_payload_with_code_400_for_nil_payload() {
        let result = InAppEventProcessing.test_buildInAppEventData(
            type: .error,
            payload: nil
        )

        XCTAssertNil(result?.href)
        XCTAssertEqual(result?.code, 400)
        XCTAssertNil(result?.message)
    }
}
