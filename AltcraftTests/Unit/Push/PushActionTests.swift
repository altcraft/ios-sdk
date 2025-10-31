//
//  PushActionTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PushActionTests
 *
 * Positive scenarios:
 *  - test_1: Missing buttons emits error from pushClickAction.
 *  - test_2: Invalid buttons JSON emits error from pushClickAction.
 *  - test_3: Default action uses click URL with no error if cannot open.
 *  - test_4: Button index out of range emits error from handleButtonAction.
 *  - test_5: Button two uses second button link with no error path.
 */
final class PushActionTests: XCTestCase {

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] in self?.events.append($0) } }
        func stop()  { SDKEvents.shared.unsubscribe() }
    }

    /// test_1: Missing buttons emits error from pushClickAction
    func test_1_missingButtons_emitsError_from_pushClickAction() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        pushClickAction(userInfo: [:], identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        XCTAssertFalse(spy.events.isEmpty)
        let last = spy.events.last
        XCTAssertTrue(last is ErrorEvent)
        XCTAssertEqual(last?.function, "pushClickAction()")
    }

    /// test_2: Invalid buttons JSON emits error from pushClickAction
    func test_2_invalidButtonsJSON_emitsError_from_pushClickAction() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        let payload: [String: Any] = [Constants.UserInfoKeys.buttons: "{ not-json }"]
        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        XCTAssertFalse(spy.events.isEmpty)
        let last = spy.events.last
        XCTAssertTrue(last is ErrorEvent)
        XCTAssertEqual(last?.function, "pushClickAction()")
    }

    /// test_3: Default action uses click URL with no error if cannot open
    func test_3_defaultAction_usesClickUrl_noErrorIfCannotOpen() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        let payload: [String: Any] = [
            Constants.UserInfoKeys.buttons: "[]",
            Constants.UserInfoKeys.clickUrl: "myapp://deeplink/path"
        ]

        pushClickAction(userInfo: payload, identifier: Constants.ButtonIdentifier.defaultNotificationAction)

        let anyPushActionErrors = spy.events.contains {
            $0.function == "pushClickAction()" && ($0 is ErrorEvent)
        }
        XCTAssertFalse(anyPushActionErrors)
    }

    /// test_4: Button index out of range emits error from handleButtonAction
    func test_4_buttonIndex_outOfRange_emitsError_from_handleButtonAction() throws {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

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

    /// test_5: Button two uses second button link with no error path
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

        let anyErrors = spy.events.contains {
            ($0.function == "pushClickAction()" || $0.function == "handleButtonAction()") && ($0 is ErrorEvent)
        }
        XCTAssertFalse(anyErrors)
    }
}
