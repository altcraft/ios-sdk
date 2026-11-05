//
//  SDKEventsTests.swift
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
 * SDKEventsTests
 *
 * Positive scenarios:
 *  - test_1: Subscribe and emit delivers event.
 *  - test_2: Unsubscribe blocks emission.
 *  - test_3: Subscribe replaces previous subscriber.
 *  - test_4: Event emits general event with message and value.
 *  - test_5: Error event extracts from strings and SDK errors.
 *  - test_6: Error event with NSError sets message from description.
 *  - test_7: Retry event with NSError sets message from description.
 *  - test_8: Event value compact maps nil entries.
 */
final class SDKEventsTests: XCTestCase {

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

        let e = Event(function: marker, event: nil, message: Self.msgHello, value: ["k": 1])
        SDKEvents.shared.emit(event: e)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(received)
        XCTAssertEqual(received?.message, Self.msgHello)
        XCTAssertEqual(received?.value?["k"] as? Int, 1)
    }

    /// test_2: Unsubscribe blocks emission
    func test_2_unsubscribe_blocksEmission() {
        let inverted = expectation(description: "should not receive")
        inverted.isInverted = true
        SDKEvents.shared.subscribe { _ in inverted.fulfill() }
        SDKEvents.shared.unsubscribe()

        let e = Event(function: fn("t2"), message: "X", value: nil)
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

        SDKEvents.shared.emit(event: Event(function: marker, message: "X", value: nil))

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(firedByNew)
    }

    /// test_4: Event emits general event with message and value
    func test_4_event_emits_general_Event_with_message_and_value() {
        let marker = fn("helper.t4")
        let exp = expectation(description: "general event t4")
        var evCaptured: Event?

        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.helper") }) { e in
            evCaptured = e
        }

        let emitted = Event(function: marker, event: nil, message: Self.msgHello, value: ["a": 42])
        SDKEvents.shared.emit(event: emitted)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(evCaptured)
        XCTAssertEqual(evCaptured?.message, Self.msgHello)
        XCTAssertEqual(evCaptured?.value?["a"] as? Int, 42)
        XCTAssertEqual(emitted.id, evCaptured?.id)
    }

    /// test_5: Error event extracts from strings and SDK errors
    func test_5_errorEvent_extracts_from_String_and_SDKError() {
        do {
            let marker = fn("err.str.t5")
            let exp = expectation(description: "string error t5")
            var ev: ErrorEvent?
            installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
                ev = e as? ErrorEvent
            }
            let emitted = errorEvent(marker, error: Self.msgStrError, eventValue: nil)
            waitForExpectations(timeout: 1.0)

            XCTAssertNotNil(ev)
            XCTAssertNil(ev?.event)
            XCTAssertEqual(ev?.message, Self.msgStrError)
            XCTAssertEqual(emitted.id, ev?.id)
        }

        do {
            let marker = fn("err.sdk.t5")
            let exp = expectation(description: "sdk error t5")
            var ev: ErrorEvent?
            installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
                ev = e as? ErrorEvent
            }
            _ = errorEvent(marker, error: SDKError.sdk(event: CoreEvents.configIsNotSet, message: Self.msgTuple), eventValue: nil)
            waitForExpectations(timeout: 1.0)

            XCTAssertNotNil(ev)
            XCTAssertEqual(ev?.event as? CoreEvents, CoreEvents.configIsNotSet)
            XCTAssertEqual(ev?.message, Self.msgTuple)
        }
    }

    /// test_6: Error event with NSError sets message from description
    func test_6_errorEvent_with_NSError_sets_message_from_description() {
        let marker = fn("err.ns.t6")
        let exp = expectation(description: "nserror error t6")
        var ev: ErrorEvent?
        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.err") }) { e in
            ev = e as? ErrorEvent
        }

        let ns = NSError(domain: Self.nsErrorDomain, code: 123, userInfo: [NSLocalizedDescriptionKey: Self.nsErrorText])
        _ = errorEvent(marker, error: ns, eventValue: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertNil(ev?.event)
        XCTAssertEqual(ev?.message, Self.nsErrorText)
    }

    /// test_7: Retry event with NSError sets message from description
    func test_7_retryEvent_with_NSError_sets_message_from_description() {
        let marker = fn("retry.ns.t7")
        let exp = expectation(description: "nserror retry t7")
        var ev: RetryEvent?
        installSubscriber(expectation: exp, match: { $0.function.contains("Unit.retry") }) { e in
            ev = e as? RetryEvent
        }

        let ns = NSError(domain: Self.nsErrorDomain, code: 321, userInfo: [NSLocalizedDescriptionKey: Self.nsErrorText])
        _ = retryEvent(marker, error: ns, eventValue: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertNil(ev?.event)
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

        let emitted = Event(function: marker, event: nil, message: "v", value: ["good": 1, "bad": nil, "str": "x"])
        SDKEvents.shared.emit(event: emitted)

        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(ev)
        XCTAssertEqual(ev?.id, emitted.id)
        XCTAssertEqual(ev?.value?["good"] as? Int, 1)
        XCTAssertEqual(ev?.value?["str"] as? String, "x")
        XCTAssertNil(ev?.value?["bad"] ?? nil)
    }
}
