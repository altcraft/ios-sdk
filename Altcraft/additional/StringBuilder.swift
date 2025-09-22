//
//  CreateMessage.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Formats the function name by replacing any parameters with `()`.
func formatFunctionName(_ functionName: String) -> String {
    let pattern = "\\(.*?\\)"
    return functionName.replacingOccurrences(of: pattern, with: "()", options: .regularExpression)
}

/// Constructs the full URL string for the push subscription request.
///
/// - Parameter baseUrl: The base URL of the API server .
/// - Returns: A complete subscribe URL string
func subscribeURL(_ apiUrl: String) -> String {
    return "\(apiUrl)/subscription/push/subscribe/"
}

/// Generates the full URL string for updating push notification subscriptions.
///
/// - Parameter apiUrl: The base API URL
/// - Returns: The complete update URL string
func updateUrl(_ apiUrl: String) -> String {
    return "\(apiUrl)/subscription/push/update/"
}

/// Constructs the full URL string for sending a push event.
///
/// - Parameters:
///   - baseUrl: The base API URL.
///   - event: The `PushEventEntity` for which the event type is appended.
/// - Returns: A complete URL string for the push event endpoint.
func pushEventURL(_ apiUrl: String, event: PushEventEntity) -> String {
    return "\(apiUrl)/event/push/\(event.type ?? "")"
}

/// Generates the full URL string for unSuspend request.
///
/// - Parameter apiUrl: The base API URL.
/// - Returns: The complete unSuspend URL string.
func unSuspendUrl(_ apiUrl: String) -> String {
    return "\(apiUrl)/subscription/push/unsuspend/"
}

/// Builds the full profile status URL based on the provided API base URL.
///
/// - Parameter apiUrl: The base URL of the API.
/// - Returns: A complete URL string for the push subscription status endpoint.
func profileUrl(_ apiUrl: String) -> String {
    return "\(apiUrl)/subscription/push/status/"
}

/// Builds a JSON string from `JWTMatching` fields.
///
/// - Parameter matchingFields: The validated `JWTMatching` object.
/// - Returns: A JSON-formatted string with `db_id`, `matching`, and `matching_value`.
func matchingAsString(dbId: Int, matching: String, value: String) -> String {
    return """
    {
      "\(Constants.AuthKeys.dbId)": "\(dbId)",
      "\(Constants.AuthKeys.matching)": "\(matching)",
      "\(Constants.AuthKeys.matchingID)": "\(value)"
    }
    """
}
