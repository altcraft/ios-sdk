//
//  ActionFieldBuilderTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ActionFieldBuilderTests
 *
 * Positive scenarios:
 *  - test_1: Set builds correct flattened entry with a string value.
 *  - test_2: Incr builds correct entry with an int value.
 *  - test_3: Add builds correct entry with an array value.
 *  - test_4: Delete builds correct entry with a bool value.
 *  - test_5: Upsert builds correct entry with a string value.
 *  - test_6: Unset includes the value key with a nil payload.
 */
final class ActionFieldBuilderTests: IsolatedTestCase {

    private let keyName      = "name"
    private let keyScore     = "score"
    private let keyTags      = "tags"
    private let keyIsActive  = "isActive"
    private let keyEmail     = "email"
    private let keyMidName   = "middleName"

    private let nameAlice    = "Alice"
    private let emailValue   = "user@example.com"
    private let tagsArray    = ["new", "hot"]

    private let msgMissingInner   = "Expected inner map for top-level key"
    private let msgActionMismatch = "Action field does not match expected value"
    private let msgValueMissing   = "'value' key must be present"
    private let msgValueMismatch  = "Inner 'value' differs from expected"

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

    private func assertAction(
        _ inner: [String: Any?],
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(inner["action"] as? String, expected, msgActionMismatch, file: file, line: line)
    }

    /// test_1: Set builds correct flattened entry with a string value
    func test_1_set_buildsCorrectEntry_withString() {
        let builder = ActionFieldBuilder(key: keyName)
        let entry = builder.set(value: nameAlice)
        let inner = unpackInner(entry, key: keyName)
        assertAction(inner, equals: "set")
        XCTAssertEqual(inner["value"] as? String, nameAlice, msgValueMismatch)
    }

    /// test_2: Incr builds correct entry with an int value
    func test_2_incr_buildsCorrectEntry_withInt() {
        let builder = ActionFieldBuilder(key: keyScore)
        let delta = 3
        let entry = builder.incr(value: delta)
        let inner = unpackInner(entry, key: keyScore)
        assertAction(inner, equals: "incr")
        XCTAssertEqual(inner["value"] as? Int, delta, msgValueMismatch)
    }

    /// test_3: Add builds correct entry with an array value
    func test_3_add_buildsCorrectEntry_withArray() {
        let builder = ActionFieldBuilder(key: keyTags)
        let entry = builder.add(value: tagsArray)
        let inner = unpackInner(entry, key: keyTags)
        assertAction(inner, equals: "add")
        XCTAssertEqual(inner["value"] as? [String], tagsArray, msgValueMismatch)
    }

    /// test_4: Delete builds correct entry with a bool value
    func test_4_delete_buildsCorrectEntry_withBool() {
        let builder = ActionFieldBuilder(key: keyIsActive)
        let entry = builder.delete(value: true)
        let inner = unpackInner(entry, key: keyIsActive)
        assertAction(inner, equals: "delete")
        XCTAssertEqual(inner["value"] as? Bool, true, msgValueMismatch)
    }

    /// test_5: Upsert builds correct entry with a string value
    func test_5_upsert_buildsCorrectEntry_withString() {
        let builder = ActionFieldBuilder(key: keyEmail)
        let entry = builder.upsert(value: emailValue)
        let inner = unpackInner(entry, key: keyEmail)
        assertAction(inner, equals: "upsert")
        XCTAssertEqual(inner["value"] as? String, emailValue, msgValueMismatch)
    }

    /// test_6: Unset includes the value key with a nil payload
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
