//
//  InAppBridgeTests.swift
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
 * InAppBridgeTests
 *
 * Positive scenarios:
 * - test_1: bridge calls onEvent when message body is String.
 *
 * Edge scenarios:
 * - test_2: bridge does not call onEvent when message body is Dictionary.
 * - test_3: bridge does not call onEvent when message body is Array.
 * - test_4: bridge does not call onEvent when message body is Number.
 *
 */
@available(iOSApplicationExtension, unavailable)
final class InAppBridgeTests: IsolatedTestCase {

    /// test_1: bridge calls onEvent when message body is String
    func test_1_bridge_calls_onEvent_when_message_body_is_string() {
        var receivedJson: String?

        let bridge = InAppBridge { eventJson in
            receivedJson = eventJson
        }

        bridge.test_receive(
            body: "{\"type\":\"click\"}"
        )

        XCTAssertEqual(
            receivedJson,
            "{\"type\":\"click\"}"
        )
    }

    /// test_2: bridge does not call onEvent when message body is Dictionary
    func test_2_bridge_does_not_call_onEvent_when_message_body_is_dictionary() {
        var didCallOnEvent = false

        let bridge = InAppBridge { _ in
            didCallOnEvent = true
        }

        bridge.test_receive(
            body: [
                "type": "click"
            ]
        )

        XCTAssertFalse(
            didCallOnEvent
        )
    }

    /// test_3: bridge does not call onEvent when message body is Array
    func test_3_bridge_does_not_call_onEvent_when_message_body_is_array() {
        var didCallOnEvent = false

        let bridge = InAppBridge { _ in
            didCallOnEvent = true
        }

        bridge.test_receive(
            body: [
                "click",
                "close"
            ]
        )

        XCTAssertFalse(
            didCallOnEvent
        )
    }

    /// test_4: bridge does not call onEvent when message body is Number
    func test_4_bridge_does_not_call_onEvent_when_message_body_is_number() {
        var didCallOnEvent = false

        let bridge = InAppBridge { _ in
            didCallOnEvent = true
        }

        bridge.test_receive(
            body: 123
        )

        XCTAssertFalse(
            didCallOnEvent
        )
    }
}
