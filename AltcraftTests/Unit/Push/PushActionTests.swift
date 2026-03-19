//
//  PushActionTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
* PushActionTests
*
* Positive scenarios:
* - test_1: Missing buttons JSON emits error from pushClickAction.
* - test_2: Invalid buttons JSON emits error from pushClickAction.
* - test_3: Default action uses click URL with no error if URL cannot be opened.
* - test_4: Button index out of range emits error from handleButtonAction.
* - test_5: Button two uses second button link with no error path.
*
*/
final class PushActionTests: XCTestCase {

    private final class EventSpy {
        private(set) var events: [Event] = []
        private var expectation: XCTestExpectation?

        func start(expectation: XCTestExpectation? = nil) {
            self.expectation = expectation
            SDKEvents.shared.subscribe { [weak self] event in
                self?.events.append(event)
                self?.expectation?.fulfill()
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
            expectation = nil
        }
    }

    /// test_1: Missing buttons JSON emits error from pushClickAction
    func test_1_missing_buttons_json_emits_error_from_push_click_action() async {
        let emittedError = expectation(description: "Error event should be emitted")

        let spy = EventSpy()
        spy.start(expectation: emittedError)
        defer { spy.stop() }

        await PushAction.shared.pushClickAction(
            buttonsJSON: nil,
            clickURL: nil,
            identifier: Constants.ButtonIdentifier.defaultNotificationAction
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(lastEvent?.function, "pushClickAction()")
    }

    /// test_2: Invalid buttons JSON emits error from pushClickAction
    func test_2_invalid_buttons_json_emits_error_from_push_click_action() async {
        let emittedError = expectation(description: "Error event should be emitted")

        let spy = EventSpy()
        spy.start(expectation: emittedError)
        defer { spy.stop() }

        await PushAction.shared.pushClickAction(
            buttonsJSON: "{ not-json }",
            clickURL: nil,
            identifier: Constants.ButtonIdentifier.defaultNotificationAction
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(lastEvent?.function, "pushClickAction()")
    }

    /// test_3: Default action uses click URL with no error if URL cannot be opened
    func test_3_default_action_uses_click_url_with_no_error_if_url_cannot_be_opened() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        await PushAction.shared.pushClickAction(
            buttonsJSON: "[]",
            clickURL: "myapp://deeplink/path",
            identifier: Constants.ButtonIdentifier.defaultNotificationAction
        )

        let hasPushActionErrors = spy.events.contains {
            $0.function == "pushClickAction()" && ($0 is ErrorEvent)
        }

        XCTAssertFalse(hasPushActionErrors)
    }

    /// test_4: Button index out of range emits error from handleButtonAction
    func test_4_button_index_out_of_range_emits_error_from_handle_button_action() async throws {
        let emittedError = expectation(description: "Error event should be emitted")

        let spy = EventSpy()
        spy.start(expectation: emittedError)
        defer { spy.stop() }

        let buttonsJSON = try JSONEncoder().encode([
            ["label": "Only", "link": "https://example.com"]
        ])

        let buttonsString = String(data: buttonsJSON, encoding: .utf8)

        await PushAction.shared.pushClickAction(
            buttonsJSON: buttonsString,
            clickURL: nil,
            identifier: Constants.ButtonIdentifier.buttonThree
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(lastEvent?.function, "handleButtonAction()")
    }

    /// test_5: Button two uses second button link with no error path
    func test_5_button_two_uses_second_button_link_with_no_error_path() async throws {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let buttonsJSON = try JSONEncoder().encode([
            ["label": "First", "link": "myapp://first"],
            ["label": "Second", "link": "myapp://second"]
        ])

        let buttonsString = String(data: buttonsJSON, encoding: .utf8)

        await PushAction.shared.pushClickAction(
            buttonsJSON: buttonsString,
            clickURL: nil,
            identifier: Constants.ButtonIdentifier.buttonTwo
        )

        let hasErrors = spy.events.contains {
            ($0.function == "pushClickAction()" || $0.function == "handleButtonAction()")
            && ($0 is ErrorEvent)
        }

        XCTAssertFalse(hasErrors)
    }
}
