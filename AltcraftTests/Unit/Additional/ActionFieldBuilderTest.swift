//
// ActionFieldBuilderTest.swift
// AltcraftTests
//
// Created by Andrey Pogodin.
//
// Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ActionFieldBuilderTest
 *
 * Positive scenarios:
 *  - test_1: set builds correct flattened entry with a String value → returns entry with correct action and value.
 *  - test_2: incr builds correct entry with an Int value → returns entry with correct action and value.
 *  - test_3: add builds correct entry with an array value → returns entry with correct action and value.
 *  - test_4: delete builds correct entry with a Bool value → returns entry with correct action and value.
 *  - test_5: upsert builds correct entry with a String value → returns entry with correct action and value.
 *
 * Edge scenarios:
 *  - test_6: unset includes the "value" key with a nil payload (distinguish key-present-with-nil) → ensures nil is explicitly stored.
 */
final class ActionFieldBuilderTest: XCTestCase {

    // ---------- Keys ----------
    private let keyName      = "name"
    private let keyScore     = "score"
    private let keyTags      = "tags"
    private let keyIsActive  = "isActive"
    private let keyEmail     = "email"
    private let keyMidName   = "middleName"

    // ---------- Values ----------
    private let nameAlice    = "Alice"
    private let emailValue   = "user@example.com"
    private let tagsArray    = ["new", "hot"]

    // ---------- Assertion messages ----------
    private let msgMissingInner   = "Expected inner map for top-level key"
    private let msgActionMismatch = "Action field does not match expected value"
    private let msgValueMissing   = "'value' key must be present"
    private let msgValueMismatch  = "Inner 'value' differs from expected"

    /// Unpacks the inner `["action": String, "value": Any?]` map for a given top-level key.
    private func unpackInner(
        _ entry: [String: Any?],
        key: String
    ) -> [String: Any?] {
        guard let inner = entry[key] as? [String: Any?] else {
            XCTFail("\(msgMissingInner): \(key)")
            return [:]
        }
        return inner
    }

    /// Asserts the "action" field equals the expected value.
    private func assertAction(
        _ inner: [String: Any?],
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(inner["action"] as? String, expected, msgActionMismatch, file: file, line: line)
    }

    /// set builds correct flattened entry with a String value
    func test_1_set_buildsCorrectEntry_withString() {
        let builder = ActionFieldBuilder(key: keyName)
        let entry = builder.set(value: nameAlice)
        let inner = unpackInner(entry, key: keyName)
        assertAction(inner, equals: "set")
        XCTAssertEqual(inner["value"] as? String, nameAlice, msgValueMismatch)
    }

    /// incr builds correct entry with an Int value
    func test_2_incr_buildsCorrectEntry_withInt() {
        let builder = ActionFieldBuilder(key: keyScore)
        let delta = 3
        let entry = builder.incr(value: delta)
        let inner = unpackInner(entry, key: keyScore)
        assertAction(inner, equals: "incr")
        XCTAssertEqual(inner["value"] as? Int, delta, msgValueMismatch)
    }

    /// add builds correct entry with an array value
    func test_3_add_buildsCorrectEntry_withArray() {
        let builder = ActionFieldBuilder(key: keyTags)
        let entry = builder.add(value: tagsArray)
        let inner = unpackInner(entry, key: keyTags)
        assertAction(inner, equals: "add")
        XCTAssertEqual(inner["value"] as? [String], tagsArray, msgValueMismatch)
    }

    /// delete builds correct entry with a Bool value
    func test_4_delete_buildsCorrectEntry_withBool() {
        let builder = ActionFieldBuilder(key: keyIsActive)
        let entry = builder.delete(value: true)
        let inner = unpackInner(entry, key: keyIsActive)
        assertAction(inner, equals: "delete")
        XCTAssertEqual(inner["value"] as? Bool, true, msgValueMismatch)
    }

    /// upsert builds correct entry with a String value
    func test_5_upsert_buildsCorrectEntry_withString() {
        let builder = ActionFieldBuilder(key: keyEmail)
        let entry = builder.upsert(value: emailValue)
        let inner = unpackInner(entry, key: keyEmail)
        assertAction(inner, equals: "upsert")
        XCTAssertEqual(inner["value"] as? String, emailValue, msgValueMismatch)
    }

    /// unset includes the "value" key with a nil payload (nested Optional)
    func test_6_unset_includesNilValue() {
        let builder = ActionFieldBuilder(key: keyMidName)
        let entry = builder.unset(value: nil)
        let inner = unpackInner(entry, key: keyMidName)
        assertAction(inner, equals: "unset")
        XCTAssertTrue(inner.keys.contains("value"), msgValueMissing)
        let val = inner["value"]
        switch val {
        case .some(.none):
            XCTAssertTrue(true)
        default:
            XCTFail("Expected 'value' to be present with nil (got \(String(describing: val)))")
        }
    }
}
