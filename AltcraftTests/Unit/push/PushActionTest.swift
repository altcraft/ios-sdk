//
//  PushActionTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PushActionTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_missingButtons_emitsError_from_pushClickAction
 *  - test_2_invalidButtonsJSON_emitsError_from_pushClickAction
 *  - test_3_defaultAction_usesClickUrl_noErrorIfCannotOpen
 *  - test_4_buttonIndex_outOfRange_emitsError_from_handleButtonAction
 *  - test_5_buttonTwo_usesSecondButtonLink_noErrorPath
 *
 * Notes:
 *  - We don't assert actual URL opening (UIApplication in unit runner usually can't open custom URLs).
 *    We only assert that no ErrorEvent is emitted for valid paths and that errors are emitted for invalid payloads.
 *  - Event function names include trailing parentheses, e.g. "pushClickAction()", "handleButtonAction()".
 */
final class PushActionTests: XCTestCase {

    // MARK: - Event Spy

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] in self?.events.append($0) } }
        func stop()  { SDKEvents.shared.unsubscribe() }
    }

    // MARK: - Tests

    /// test_1_missingButtons_emitsError_from_pushClickAction
    func test_1_missingButtons_emitsError_from_pushClickAction() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        // No "buttons" key at all
        pushClickAction(userInfo: [:], identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        XCTAssertFalse(spy.events.isEmpty)
        let last = spy.events.last
        XCTAssertTrue(last is ErrorEvent)
        XCTAssertEqual(last?.function, "pushClickAction()")
    }

    /// test_2_invalidButtonsJSON_emitsError_from_pushClickAction
    func test_2_invalidButtonsJSON_emitsError_from_pushClickAction() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        // "buttons" present, but not a valid JSON array of dictionaries
        let payload: [String: Any] = [Constants.UserInfoKeys.buttons: "{ not-json }"]
        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        XCTAssertFalse(spy.events.isEmpty)
        let last = spy.events.last
        XCTAssertTrue(last is ErrorEvent)
        XCTAssertEqual(last?.function, "pushClickAction()")
    }

    /// test_3_defaultAction_usesClickUrl_noErrorIfCannotOpen
    func test_3_defaultAction_usesClickUrl_noErrorIfCannotOpen() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        // Valid empty buttons array and a deeplink that can't be opened in unit runner.
        let payload: [String: Any] = [
            Constants.UserInfoKeys.buttons: "[]",
            Constants.UserInfoKeys.clickUrl: "myapp://deeplink/path"
        ]

        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        // ensure no ErrorEvent from pushClickAction path
        let anyPushActionErrors = spy.events.contains {
            $0.function == "pushClickAction()" && ($0 is ErrorEvent)
        }
        XCTAssertFalse(anyPushActionErrors)
    }

    /// test_4_buttonIndex_outOfRange_emitsError_from_handleButtonAction
    func test_4_buttonIndex_outOfRange_emitsError_from_handleButtonAction() throws {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        // One button only; we will tap "buttonThree" (index 2) -> out of range
        let buttonsJSON = try JSONEncoder().encode([["label": "Only", "link": "https://example.com"]])
        let payload: [String: Any] = [
            Constants.UserInfoKeys.buttons: String(data: buttonsJSON, encoding: .utf8) ?? "[]"
        ]

        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.buttonThree)

        XCTAssertFalse(spy.events.isEmpty)
        let last = spy.events.last
        XCTAssertTrue(last is ErrorEvent)
        XCTAssertEqual(last?.function, "handleButtonAction()")
    }

    /// test_5_buttonTwo_usesSecondButtonLink_noErrorPath
    func test_5_buttonTwo_usesSecondButtonLink_noErrorPath() throws {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        let buttonsJSON = try JSONEncoder().encode([
            ["label": "First",  "link": "myapp://first"],
            ["label": "Second", "link": "myapp://second"]
        ])
        let payload: [String: Any] = [
            Constants.UserInfoKeys.buttons: String(data: buttonsJSON, encoding: .utf8) ?? "[]"
        ]

        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.buttonTwo)

        // no ErrorEvent expected from pushClickAction/handleButtonAction on valid path
        let anyErrors = spy.events.contains {
            ($0.function == "pushClickAction()" || $0.function == "handleButtonAction()") && ($0 is ErrorEvent)
        }
        XCTAssertFalse(anyErrors)
    }
}
