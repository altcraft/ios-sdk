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
    public func unset(value: Any?) -> [String: Any?] {
        buildFlat(action: "unset", value: value)
    }

    /// Builds an `.incr` action field.
    public func incr(value: Any?) -> [String: Any?] {
        buildFlat(action: "incr", value: value)
    }

    /// Builds an `.add` action field.
    public func add(value: Any?) -> [String: Any?] {
        buildFlat(action: "add", value: value)
    }

    /// Builds a `.delete` action field.
    public func delete(value: Any?) -> [String: Any?] {
        buildFlat(action: "delete", value: value)
    }

    /// Builds an `.upsert` action field.
    public func upsert(value: Any?) -> [String: Any?] {
        buildFlat(action: "upsert", value: value)
    }

    /// Internal helper to flatten nested action-value structure for SDK compatibility.
    private func buildFlat(action: String, value: Any?) -> [String: Any?] {
        return [
            key: [
                "action": action,
                "value": value
            ]
        ]
    }
}
