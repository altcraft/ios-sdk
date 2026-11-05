//
//  PublicPushSubscriptionTests.swift
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
 * PublicPushSubscriptionFunctionsTests
 *
 * Positive scenarios:
 *  - test_1: getStatusOfLatestSubscriptionForProvider → invalid provider emits error and returns nil.
 *  - test_2: actionField → builds all actions with expected shape.
 */
final class PublicPushSubscriptionFunctionsTests: IsolatedTestCase {

    /// Captures emitted SDK events.
    private final class EventSpy {
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] event in
                self?.events.append(event)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }
    }

    /// Sendable value box.
    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: T

        init(_ value: T) {
            self.storage = value
        }

        func set(_ value: T) {
            lock.lock()
            storage = value
            lock.unlock()
        }

        func get() -> T {
            lock.lock()
            let value = storage
            lock.unlock()
            return value
        }
    }

    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let rawElse: String = raw else { return "" }
        var s = rawElse
        if let spaceIdx = s.firstIndex(of: " ") {
            let candidate = s[..<spaceIdx]
            if candidate.first == "[" && candidate.last == "]" {
                s = String(s[s.index(after: spaceIdx)...])
            }
        }
        if let idx = s.firstIndex(of: "(") {
            return String(s[..<idx])
        }
        return s.hasSuffix("()") ? String(s.dropLast(2)) : s
    }

    /// test_1: getStatusOfLatestSubscriptionForProvider invalid provider emits error and returns nil
    func test_1_getStatusOfLatestSubscriptionForProvider_invalidProvider_emitsError_andReturnsNil() {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.events.count
        let invalidProvider = "__nope__"

        let exp = expectation(description: "completion called")
        let received = Box<ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?>(nil)

        SubscriptionAPI.shared.latestForProvider(
            provider: invalidProvider
        ) { response in
            received.set(response)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)

        XCTAssertNil(received.get(), "Completion must receive nil for invalid provider")

        let newEvents = Array(spy.events.dropFirst(before))
        let hasError = newEvents.contains {
            ($0 is ErrorEvent) &&
            normalizeFunctionName($0.function) == "getStatusOfLatestSubscriptionForProvider"
        }

        XCTAssertTrue(hasError, "Invalid provider must emit ErrorEvent")
    }

    /// test_2: actionField builds all actions with expected shape
    func test_2_actionField_buildsAllActions_withExpectedShape() {
        let builder = SubscriptionAPI.shared.actionField(key: "_score")

        let set = builder.set(value: 10)
        let unset = builder.unset(value: nil)
        let incr = builder.incr(value: 2)
        let add = builder.add(value: ["a", "b"])
        let del = builder.delete(value: "old")
        let upsert = builder.upsert(value: ["k": "v"])

        func assertShape(
            _ entry: [String: Any?],
            action: String,
            valueCheck: (Any?) -> Bool,
            line: UInt = #line
        ) {
            XCTAssertEqual(entry.keys.count, 1, line: line)

            let payload = entry["_score"] as? [String: Any?]
            XCTAssertNotNil(payload, line: line)
            XCTAssertEqual(payload?["action"] as? String, action, line: line)
            XCTAssertTrue(valueCheck(payload?["value"] ?? nil), line: line)
        }

        assertShape(set, action: "set") { value in
            (value as? Int) == 10
        }

        assertShape(unset, action: "unset") { value in
            value == nil
        }

        assertShape(incr, action: "incr") { value in
            (value as? Int) == 2
        }

        assertShape(add, action: "add") { value in
            (value as? [String]) == ["a", "b"]
        }

        assertShape(del, action: "delete") { value in
            (value as? String) == "old"
        }

        assertShape(upsert, action: "upsert") { value in
            let dict = value as? [String: String]
            return dict?["k"] == "v"
        }
    }
}
