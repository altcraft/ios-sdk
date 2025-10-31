//
//  ActionFieldBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Builds profile field action entries for structured updates compatible with `[String: Any?]`.
///
/// Supported actions: `set`, `unset`, `incr`, `add`, `delete`, `upsert`.
public struct ActionFieldBuilder {
    private let key: String

    /// Initializes the builder with a profile field key.
    ///
    /// - Parameter key: The profile field key that the actions will target.
    init(key: String) {
        self.key = key
    }

    /// Builds a `.set` action field.
    ///
    /// - Parameter value: Value to set.
    /// - Returns: A key-value entry for structured profile update.
    public func set(value: Any?) -> [String: Any?] {
        buildFlat(action: "set", value: value)
    }

    /// Builds an `.unset` action field.
    ///
    /// - Parameter value: Optional payload (usually ignored for `unset`).
    /// - Returns: A key-value entry for a structured profile update.
    public func unset(value: Any?) -> [String: Any?] {
        buildFlat(action: "unset", value: value)
    }

    /// Builds an `.incr` action field.
    ///
    /// - Parameter value: Increment value (numeric).
    /// - Returns: A key-value entry for a structured profile update.
    public func incr(value: Any?) -> [String: Any?] {
        buildFlat(action: "incr", value: value)
    }

    /// Builds an `.add` action field.
    ///
    /// - Parameter value: Value to add (e.g., element for a set/array field).
    /// - Returns: A key-value entry for a structured profile update.
    public func add(value: Any?) -> [String: Any?] {
        buildFlat(action: "add", value: value)
    }

    /// Builds a `.delete` action field.
    ///
    /// - Parameter value: Value to delete (e.g., element to remove) or identifier.
    /// - Returns: A key-value entry for a structured profile update.
    public func delete(value: Any?) -> [String: Any?] {
        buildFlat(action: "delete", value: value)
    }

    /// Builds an `.upsert` action field.
    ///
    /// - Parameter value: Value to insert or update.
    /// - Returns: A key-value entry for a structured profile update.
    public func upsert(value: Any?) -> [String: Any?] {
        buildFlat(action: "upsert", value: value)
    }

    /// Internal helper to flatten the action/value structure for SDK compatibility.
    ///
    /// - Parameters:
    ///   - action: Action name (`"set"`, `"unset"`, `"incr"`, `"add"`, `"delete"`, `"upsert"`).
    ///   - value: Associated value for the action (if applicable).
    /// - Returns: A single-entry dictionary keyed by the field name with an `action`/`value` pair.
    private func buildFlat(action: String, value: Any?) -> [String: Any?] {
        return [
            key: [
                "action": action,
                "value": value
            ]
        ]
    }
}
