//
//  InAppEmitterTests.swift
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
 * InAppEmitterTests
 *
 * Positive scenarios:
 *  - test_1: subscribe then emit delivers JSON to subscriber.
 *  - test_2: multiple emits deliver all messages.
 *  - test_3: unsubscribe stops delivery.
 *  - test_4: emit with no subscriber does not crash.
 *  - test_5: replacing subscriber delivers to new subscriber only.
 *
 * Edge scenarios:
 *  - test_6: emit after unsubscribe and re-subscribe works.
 *  - test_7: empty string JSON is delivered correctly.
 */
final class InAppEmitterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InAppEmitter.shared.unsubscribe()
    }

    override func tearDown() {
        InAppEmitter.shared.unsubscribe()
        super.tearDown()
    }

    /// test_1: subscribe then emit delivers JSON to subscriber
    func test_1_subscribeThenEmit_deliversJSON() {
        let received = ReceivedStrings()
        InAppEmitter.shared.subscribe { json in
            received.add(json)
        }

        InAppEmitter.shared.emit(json: "{\"test\":1}")

        runMainLoop()
        XCTAssertEqual(received.values, ["{\"test\":1}"])
    }

    /// test_2: multiple emits deliver all messages
    func test_2_multipleEmits_deliverAll() {
        let received = ReceivedStrings()
        InAppEmitter.shared.subscribe { json in
            received.add(json)
        }

        InAppEmitter.shared.emit(json: "a")
        InAppEmitter.shared.emit(json: "b")
        InAppEmitter.shared.emit(json: "c")

        runMainLoop()
        XCTAssertEqual(received.values, ["a", "b", "c"])
    }

    /// test_3: unsubscribe stops delivery
    func test_3_unsubscribe_stopsDelivery() {
        let received = ReceivedStrings()
        InAppEmitter.shared.subscribe { json in
            received.add(json)
        }

        InAppEmitter.shared.emit(json: "before")
        runMainLoop()

        InAppEmitter.shared.unsubscribe()
        InAppEmitter.shared.emit(json: "after")
        runMainLoop()

        XCTAssertEqual(received.values, ["before"])
    }

    /// test_4: emit with no subscriber does not crash
    func test_4_noSubscriber_noCrash() {
        XCTAssertNoThrow {
            InAppEmitter.shared.emit(json: "test")
        }
    }

    /// test_5: replacing subscriber delivers to new subscriber only
    func test_5_replaceSubscriber_deliversToNewOnly() {
        let first = ReceivedStrings()
        let second = ReceivedStrings()

        InAppEmitter.shared.subscribe { json in
            first.add(json)
        }
        InAppEmitter.shared.subscribe { json in
            second.add(json)
        }

        InAppEmitter.shared.emit(json: "msg")
        runMainLoop()

        XCTAssertEqual(first.values, [])
        XCTAssertEqual(second.values, ["msg"])
    }

    /// test_6: emit after unsubscribe and re-subscribe works
    func test_6_unsubscribeResubscribe_works() {
        let received = ReceivedStrings()

        InAppEmitter.shared.subscribe { _ in }
        InAppEmitter.shared.unsubscribe()

        InAppEmitter.shared.subscribe { json in
            received.add(json)
        }

        InAppEmitter.shared.emit(json: "hello")
        runMainLoop()

        XCTAssertEqual(received.values, ["hello"])
    }

    /// test_7: empty string JSON is delivered correctly
    func test_7_emptyStringJSON_delivered() {
        let received = ReceivedStrings()
        InAppEmitter.shared.subscribe { json in
            received.add(json)
        }

        InAppEmitter.shared.emit(json: "")
        runMainLoop()

        XCTAssertEqual(received.values, [""])
    }

    private func runMainLoop() {
        let exp = expectation(description: "main loop drain")
        DispatchQueue.main.async {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
}

/// Sendable collector for received strings.
private final class ReceivedStrings: @unchecked Sendable {
    private let lock = NSLock()
    private var _storage: [String] = []

    func add(_ s: String) {
        lock.lock()
        _storage.append(s)
        lock.unlock()
    }

    var values: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _storage
    }
}
