//
//  PublicPushSubscriptionFunctionsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PublicPushSubscriptionFunctionsTests
 *
 * Positive scenarios:
 *  - test_1: getStatusOfLatestSubscriptionForProvider → invalid provider emits error and returns nil.
 *  - test_2: actionFieldBuilder → builds all actions with expected shape.
 *  - test_3: actionFieldBuilder mergeFields → overrides on conflict and keeps all keys.
 */
final class PublicPushSubscriptionFunctionsTests: XCTestCase {

    private final class EventSpy {
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] ev in
                self?.events.append(ev)
            }
        }
        func stop() { SDKEvents.shared.unsubscribe() }
    }
    
    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") {
            return String(raw[..<idx])
        }
        return raw.hasSuffix("()") ? String(raw.dropLast(2)) : raw
    }

    /// test_1: getStatusOfLatestSubscriptionForProvider invalid provider emits error and returns nil
    func test_1_getStatusOfLatestSubscriptionForProvider_invalidProvider_emitsError_andReturnsNil() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let before = spy.events.count

        let invalid = "__nope__"
        let exp = expectation(description: "completion called")
        var received: ResponseWithHttp?
        PublicPushSubscriptionFunctions.shared.getStatusOfLatestSubscriptionForProvider(provider: invalid) {
            received = $0
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertNil(received, "Completion must receive nil for invalid provider")

        let newEvents = Array(spy.events.dropFirst(before))
        let hasErrorFromAPI = newEvents.contains {
            ($0 is ErrorEvent) && normalizeFunctionName($0.function) == "getStatusOfLatestSubscriptionForProvider"
        }
        XCTAssertTrue(hasErrorFromAPI, "Invalid provider must emit ErrorEvent")
    }

    /// test_2: actionFieldBuilder builds all actions with expected shape
    func test_2_actionFieldBuilder_buildsAllActions_withExpectedShape() {
        let b = PublicPushSubscriptionFunctions.shared.actionField(key: "_score")

        let set   = b.set(value: 10)
        let unset = b.unset(value: nil)
        let incr  = b.incr(value: 2)
        let add   = b.add(value: ["a", "b"])
        let del   = b.delete(value: "old")
        let up    = b.upsert(value: ["k":"v"])

        func assertShape(_ entry: [String: Any?], action: String, valueCheck: (Any?) -> Bool, line: UInt = #line) {
            XCTAssertEqual(entry.keys.count, 1, line: line)
            let payload = entry["_score"] as? [String: Any?]
            XCTAssertNotNil(payload, line: line)
            XCTAssertEqual(payload?["action"] as? String, action, line: line)
            XCTAssertTrue(valueCheck(payload?["value"] ?? nil), line: line)
        }

        assertShape(set,   action: "set",   valueCheck: { ($0 as? Int) == 10 })
        assertShape(unset, action: "unset", valueCheck: { $0 == nil })
        assertShape(incr,  action: "incr",  valueCheck: { ($0 as? Int) == 2 })
        assertShape(add,   action: "add",   valueCheck: { ($0 as? [String]) == ["a", "b"] })
        assertShape(del,   action: "delete",valueCheck: { ($0 as? String) == "old" })
        assertShape(up,    action: "upsert",valueCheck: { ( ($0 as? [String: String])?["k"] ) == "v" })
    }

    /// test_3: actionFieldBuilder mergeFields overrides on conflict and keeps all keys
    func test_3_actionFieldBuilder_mergeFields_overridesOnConflict_andKeepsAllKeys() {
        let name = PublicPushSubscriptionFunctions.shared.actionField(key: "_fname").set(value: "Andrey")
        let nameOverride = PublicPushSubscriptionFunctions.shared.actionField(key: "_fname").set(value: "A.")
        let age = PublicPushSubscriptionFunctions.shared.actionField(key: "_age").incr(value: 1)
        let simple: [String: Any?] = ["simple_field": "value"]

        let merged = mergeFields(name, age, simple, nameOverride)

        XCTAssertEqual(Set(merged.keys), Set(["_fname", "_age", "simple_field"]))

        if let fnamePayload = merged["_fname"] as? [String: Any?] {
            XCTAssertEqual(fnamePayload["action"] as? String, "set")
            XCTAssertEqual(fnamePayload["value"] as? String, "A.")
        } else {
            XCTFail("_fname payload missing or wrong type")
        }

        if let agePayload = merged["_age"] as? [String: Any?] {
            XCTAssertEqual(agePayload["action"] as? String, "incr")
            XCTAssertEqual(agePayload["value"] as? Int, 1)
        } else {
            XCTFail("_age payload missing or wrong type")
        }

        XCTAssertEqual(merged["simple_field"] as? String, "value")
    }
}
