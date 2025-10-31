//
//  SDKEventsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * SDKEventsTests
 *
 * Positive scenarios:
 *  - test_1: Subscribe and emit delivers event.
 *  - test_2: Unsubscribe blocks emission.
 *  - test_3: Subscribe replaces previous subscriber.
 *  - test_4: Event emits general event with code and message.
 *  - test_5: Error event extracts from string and tuples.
 *  - test_6: Error event with NSError sets code 400.
 *  - test_7: Retry event with NSError sets code 500.
 *  - test_8: Event value compact maps nil entries.
 */
final class SDKEventsTests: XCTestCase {

    private static let codeOK = 200
    private static let codeClient = 400
    private static let codeRetry = 500

    private static let msgHello = "hello"
    private static let msgStrError = "string-error"
    private static let msgTuple = "tuple-msg"
    private static let nsErrorDomain = "Unit"
    private static let nsErrorText = "ns-error"

    override func setUp() {
        super.setUp()
        SDKEvents.shared.unsubscribe()
    }

    override func tearDown() {
        SDKEvents.shared.unsubscribe()
        super.tearDown()
    }

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

    private func fn(_ suffix: String) -> String { "Unit.\(suffix)" }

    /// test_1: Subscribe and emit delivers event
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

    /// test_2: Unsubscribe blocks emission
    func test_2_unsubscribe_blocksEmission() {
        let inverted = expectation(description: "should not receive")
        inverted.isInverted = true
        SDKEvents.shared.subscribe { _ in inverted.fulfill() }
        SDKEvents.shared.unsubscribe()

        let e = Event(function: fn("t2"), message: "X", eventCode: 0, value: nil)
        SDKEvents.shared.emit(event: e)

        waitForExpectations(timeout: 0.5)
    }

    /// test_3: Subscribe replaces previous subscriber
    func test_3_subscribe_replacesPreviousSubscriber() {
        let marker = fn("t3")
        let shouldNotFire = expectation(description: "old subscriber")
        shouldNotFire.isInverted = true

        SDKEvents.shared.subscribe { ev in
            if ev.function.contains(marker) {
                shouldNotFire.fulfill()
            }
        }

        let exp = expectation(description: "new subscriber")
        var firedByNew = false

        SDKEvents.shared.subscribe { ev in
            guard ev.function.contains(marker) else { return }
            firedByNew = true
            SDKEvents.shared.unsubscribe()
            exp.fulfill()
        }

        SDKEvents.shared.emit(event: Event(function: marker, message: "X", eventCode: 0, value: nil))

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(firedByNew)
    }

    /// test_4: Event emits general event with code and message
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

    /// test_5: Error event extracts from string and tuples
    func test_5_errorEvent_extracts_from_String_and_tuples() {
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

    /// test_6: Error event with NSError sets code 400
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

    /// test_7: Retry event with NSError sets code 500
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

    /// test_8: Event value compact maps nil entries
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
