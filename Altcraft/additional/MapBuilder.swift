//
//  MapBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Creates a map containing event details based on the provided parameters.
///
/// - Parameters:
///   - uid: The event ID (optional).
///   - type: The push event type (optional).
///   - code: The HTTP status code (optional).
///   - error: The error code or message (optional).
///   - text: Additional event-related text (optional).
///   - profile: The profile data (optional).
/// - Returns: A map with keys "uid", "type", "code", "error", "text", and "profile" as needed.
func mapValue(
    code: Int? = nil,
    response: Response? = nil,
    uid: String? = nil,
    type: String? = nil
) -> [String: Any] {
    var eventMap: [String: Any] = [:]
    
    if let uid = uid { eventMap[Constants.MapKeys.uid] = uid }
    if let type = type { eventMap[Constants.MapKeys.type] = type }
    
    eventMap[Constants.MapKeys.responseWithHttp] = ResponseWithHttp(
        httpCode: code, response: response
    )

    return eventMap
}

/// Merges multiple dictionaries of type `[String: Any?]` into a single dictionary.
///
/// In case of key conflicts, the value from the later dictionary in the list overrides the previous one.
///
/// - Parameter entries: A variadic list of dictionaries to merge.
/// - Returns: A single merged dictionary containing all key-value pairs.
public func mergeFields(_ entries: [String: Any?]...) -> [String: Any?] {
    entries.reduce(into: [:]) { result, next in
        result.merge(next) { _, new in new }
    }
}
