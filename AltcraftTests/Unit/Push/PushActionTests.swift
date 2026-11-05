//
//  PushActionTests.swift
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

    /// Captures emitted SDK events.
    private final class EventSpy {
        private(set) var events: [Event] = []
        private var expectation: XCTestExpectation?
        private var fulfilled = false

        func start(expectation: XCTestExpectation? = nil) {
            self.expectation = expectation
            self.fulfilled = false
            SDKEvents.shared.subscribe { [weak self] event in
                guard let self else { return }
                self.events.append(event)
                if !self.fulfilled, let exp = self.expectation, event is ErrorEvent {
                    self.fulfilled = true
                    exp.fulfill()
                }
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
            expectation = nil
            fulfilled = false
        }

        /// Removes the `[altcraft-<module>] ` prefix from the function name.
        func functionName(_ event: Event) -> String {
            let fn = event.function
            if let range = fn.range(of: " ") {
                let prefix = fn[..<range.lowerBound]
                if prefix.first == "[" && prefix.last == "]" {
                    return String(fn[range.upperBound...])
                }
            }
            return fn
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
            identifier: PushConstants.ButtonIdentifier.defaultNotificationAction
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(spy.functionName(lastEvent ?? Event(function: "")), "pushClickAction()")
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
            identifier: PushConstants.ButtonIdentifier.defaultNotificationAction
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(spy.functionName(lastEvent ?? Event(function: "")), "pushClickAction()")
    }

    /// test_3: Default action uses click URL with no error if URL cannot be opened
    func test_3_default_action_uses_click_url_with_no_error_if_url_cannot_be_opened() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        await PushAction.shared.pushClickAction(
            buttonsJSON: "[]",
            clickURL: "myapp://deeplink/path",
            identifier: PushConstants.ButtonIdentifier.defaultNotificationAction
        )

        let hasPushActionErrors = spy.events.contains {
            spy.functionName($0) == "pushClickAction()" && ($0 is ErrorEvent)
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
            identifier: PushConstants.ButtonIdentifier.buttonThree
        )

        await fulfillment(of: [emittedError], timeout: 1.0)

        XCTAssertFalse(spy.events.isEmpty)

        let lastEvent = spy.events.last
        XCTAssertTrue(lastEvent is ErrorEvent)
        XCTAssertEqual(spy.functionName(lastEvent ?? Event(function: "")), "handleButtonAction()")
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
            identifier: PushConstants.ButtonIdentifier.buttonTwo
        )

        let hasErrors = spy.events.contains {
            (spy.functionName($0) == "pushClickAction()" || spy.functionName($0) == "handleButtonAction()")
            && ($0 is ErrorEvent)
        }

        XCTAssertFalse(hasErrors)
    }
}
