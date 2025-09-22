//
//  SDKEventsTests.swift
//  AltcraftTests
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * SDKEventsTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_subscribe_and_emit_deliversEvent
 *  - test_2_unsubscribe_blocksEmission
 *  - test_3_subscribe_replacesPreviousSubscriber
 *  - test_4_event_emits_general_Event_with_code_and_message
 *  - test_5_errorEvent_extracts_from_String_and_tuples
 *  - test_6_errorEvent_with_NSError_sets_code_400
 *  - test_7_retryEvent_with_NSError_sets_code_500
 *  - test_8_event_value_compactMaps_nil_entries
 *
 * Notes:
 *  - Uses the shared singleton; each test installs its own subscriber.
 *  - To avoid cross-test interference (when running the whole suite/parallel),
 *    each test filters events by a unique function marker and unsubscribes
 *    immediately after the first match.
 */
final class SDKEventsTests: XCTestCase {

    // MARK: - Constants

    private static let codeOK = 200
    private static let codeClient = 400
    private static let codeRetry = 500

    private static let msgHello = "hello"
    private static let msgStrError = "string-error"
    private static let msgTuple = "tuple-msg"
    private static let nsErrorDomain = "Unit"
    private static let nsErrorText = "ns-error"

    // MARK: - Suite isolation

    override func setUp() {
        super.setUp()
        // Ensure no leftover subscriber spills into this test
        SDKEvents.shared.unsubscribe()
    }

    override func tearDown() {
        // Clean up after the test
        SDKEvents.shared.unsubscribe()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Installs a temporary subscriber that:
    ///  - filters incoming events with `match`
    ///  - captures exactly once
    ///  - immediately unsubscribes after the first match
    ///  - disables over-fulfill assertion for safety
    private func installSubscriber(
        expectation exp: XCTestExpectation,
        match: @escaping (Event) -> Bool,
        capture: @escaping (Event) -> Void = { _ in }
    ) {
        exp.assertForOverFulfill = false
        SDKEvents.shared.subscribe { ev in
            guard match(ev) else { return }
            capture(ev)
            SDKEvents.shared.unsubscribe()
            exp.fulfill()
        }
    }

    /// Convenience: unique function marker for each test to avoid cross-capture.
    private func fn(_ suffix: String) -> String { "Unit.\(suffix)" }

    // MARK: - Tests

    /// Verifies event delivery to the active subscriber.
    func test_1_subscribe_and_emit_deliversEvent() {
        let marker = fn("t1")
        let exp = expectation(description: "receive event t1")
        var received: Event?

        installSubscriber(expectation: exp, match: { $0.function.contains(marker) }) { ev in
            received = ev
        }

        let e = Event(function: marker, message: Self.msgHello, eventCode: Self.codeOK, value: ["k": 1])
        SDKEvents.shared.emit(event: e)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.message, Self.msgHello)
        XCTAssertEqual(received?.eventCode, Self.codeOK)
        XCTAssertEqual(received?.value?["k"] as? Int, 1)
    }

    /// Ensures `unsubscribe()` prevents further deliveries.
    func test_2_unsubscribe_blocksEmission() {
        let inverted = expectation(description: "should not receive").thenInverted()
        SDKEvents.shared.subscribe { _ in inverted.fulfill() }
        SDKEvents.shared.unsubscribe()

        let e = Event(function: fn("t2"), message: "X", eventCode: 0, value: nil)
        SDKEvents.shared.emit(event: e)

        waitForExpectations(timeout: 0.5)
    }

    /// Confirms a new subscriber replaces the previous one.
    func test_3_subscribe_replacesPreviousSubscriber() {
        let shouldNotFire = expectation(description: "old subscriber").thenInverted()
        SDKEvents.shared.subscribe { _ in shouldNotFire.fulfill() }

        let exp = expectation(description: "new subscriber")
        var firedByNew = false
        SDKEvents.shared.subscribe { _ in
            firedByNew = true
            exp.fulfill()
        }

        SDKEvents.shared.emit(event: Event(function: fn("t3"), message: "X", eventCode: 0, value: nil))

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(firedByNew)
    }

    /// Validates `event(_:event:value:)` builds and emits a general `Event`.
    func test_4_event_emits_general_Event_with_code_and_message() {
        let marker = fn("helper.t4")
        let exp = expectation(description: "general event t4")
        var evCaptured: Event?

        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.helper") }) { e in
            evCaptured = e
        }

        let emitted = event(marker, event: (Self.codeOK, Self.msgHello), value: ["a": 42])

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(evCaptured)
        XCTAssertEqual(evCaptured?.eventCode, Self.codeOK)
        XCTAssertEqual(evCaptured?.message, Self.msgHello)
        XCTAssertEqual(evCaptured?.value?["a"] as? Int, 42)
        XCTAssertEqual(emitted.id, evCaptured?.id)
    }

    /// Checks `errorEvent` extraction for `String` and `(Int,String)`.
    func test_5_errorEvent_extracts_from_String_and_tuples() {
        // String -> code 0, message as-is
        do {
            let marker = fn("err.str.t5")
            let exp = expectation(description: "string error t5")
            var ev: ErrorEvent?
            installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
                ev = e as? ErrorEvent
            }
            let emitted = errorEvent(marker, error: Self.msgStrError, value: nil)
            waitForExpectations(timeout: 1.0)

            XCTAssertNotNil(ev)
            XCTAssertEqual(ev?.eventCode, 0)
            XCTAssertEqual(ev?.message, Self.msgStrError)
            XCTAssertEqual(emitted.id, ev?.id)
        }

        // Tuple -> exact code and message
        do {
            let marker = fn("err.tuple.t5")
            let exp = expectation(description: "tuple error t5")
            var ev: ErrorEvent?
            installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
                ev = e as? ErrorEvent
            }
            _ = errorEvent(marker, error: (Self.codeClient, Self.msgTuple), value: nil)
            waitForExpectations(timeout: 1.0)

            XCTAssertNotNil(ev)
            XCTAssertEqual(ev?.eventCode, Self.codeClient)
            XCTAssertEqual(ev?.message, Self.msgTuple)
        }
    }

    /// Ensures `NSError` maps to code 400 for `errorEvent`.
    func test_6_errorEvent_with_NSError_sets_code_400() {
        let marker = fn("err.ns.t6")
        let exp = expectation(description: "nserror error t6")
        var ev: ErrorEvent?
        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
            ev = e as? ErrorEvent
        }

        let ns = NSError(domain: Self.nsErrorDomain, code: 123, userInfo: [NSLocalizedDescriptionKey: Self.nsErrorText])
        _ = errorEvent(marker, error: ns, value: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertEqual(ev?.eventCode, Self.codeClient)
        XCTAssertEqual(ev?.message, Self.nsErrorText)
    }

    /// Ensures `NSError` maps to code 500 for `retryEvent`.
    func test_7_retryEvent_with_NSError_sets_code_500() {
        let marker = fn("retry.ns.t7")
        let exp = expectation(description: "nserror retry t7")
        var ev: RetryEvent?
        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.retry") }) { e in
            ev = e as? RetryEvent
        }

        let ns = NSError(domain: Self.nsErrorDomain, code: 321, userInfo: [NSLocalizedDescriptionKey: Self.nsErrorText])
        _ = retryEvent(marker, error: ns, value: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertEqual(ev?.eventCode, Self.codeRetry)
        XCTAssertEqual(ev?.message, Self.nsErrorText)
    }

    /// Asserts `value` dictionary drops nil entries via `compactMapValues`.
    func test_8_event_value_compactMaps_nil_entries() {
        let marker = fn("value.t8")
        let exp = expectation(description: "value compact map t8")
        var ev: Event?
        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.value") }) { e in
            ev = e
        }

        let emitted = event(marker, event: (1, "v"), value: ["good": 1, "bad": nil, "str": "x"])

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertEqual(ev?.id, emitted.id)
        XCTAssertEqual(ev?.value?["good"] as? Int, 1)
        XCTAssertEqual(ev?.value?["str"] as? String, "x")
        XCTAssertNil(ev?.value?["bad"] ?? nil)
    }
}

// MARK: - Small XCTest convenience

private extension XCTestExpectation {
    /// Marks expectation as inverted and returns it for chaining.
    func thenInverted() -> XCTestExpectation {
        isInverted = true
        return self
    }
}

