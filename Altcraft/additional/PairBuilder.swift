//
//  PairBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Maps request names to (5xx retryable, 4xx non-retryable) error codes.
private let errorCodeMap: [String: (code5xx: Int, code4xx: Int)] = [
    Constants.RequestName.subscribe: (530, 430),
    Constants.RequestName.update: (531, 431),
    Constants.RequestName.pushEvent: (534, 434),
    Constants.RequestName.mobileEvent: (535, 435)
]

/// Returns a predefined error code and formatted error message based on the request name.
/// - Parameters:
///   - requestName: The logical request name (e.g., "push/subscribe").
///   - code: The HTTP status code returned by the server.
///   - response: The parsed API response object.
///   - type: Optional event type for additional context (only used for push events).
///   - name: Optional mobile event name for additional context (only used for mobile events).
/// - Returns: A tuple containing (custom error code, formatted error message).
internal func createErrorPair(
    requestName: String,
    code: Int?,
    response: Response?,
    type: String?,
    name: String?
) -> (Int, String) {
    let errorCode = response?.error ?? 0
    let errorText = response?.errorText ?? ""
    let httpCode = code ?? 0

    var baseMessage = """
    request: \(requestName), \
    http code: \(httpCode), \
    error: \(errorCode), \
    errorText: \(errorText)
    """
    
    if requestName == Constants.RequestName.pushEvent, let type {
        baseMessage += ", type: \(type)"
    }

    if requestName == Constants.RequestName.mobileEvent, let name {
        baseMessage += ", name: \(name)"
    }

    if let (code5xx, code4xx) = errorCodeMap[requestName] {
        return (500...599).contains(httpCode)
            ? (code5xx, baseMessage)
            : (code4xx, baseMessage)
    }

    switch requestName {
    case Constants.RequestName.unsuspend:
        return (432, baseMessage)
    case Constants.RequestName.status:
        return (433, baseMessage)
    default:
        return (500...599).contains(httpCode)
            ? (539, "unknown request: \(baseMessage)")
            : (439, "unknown request: \(baseMessage)")
    }
}

/// Returns a success code and message based on the request name.
///
/// - Parameters:
///   - requestName: Logical name of the request (e.g. "push/subscribe").
///   - type: Optional event type for additional context (only used for push events).
///   - name: Optional mobile event name for additional context (only used for mobile events).
/// - Returns: A tuple with:
///   - Int: Success code,
///   - String: Success message or `"unknown request"` if unmatched.
func createSuccessPair(
    requestName: String,
    type: String?,
    name: String?
) -> (Int, String) {
    switch requestName {
    case Constants.RequestName.subscribe:
        return (230, Constants.SDKSuccessMessage.subscribeSuccess)
    case Constants.RequestName.update:
        return (231, Constants.SDKSuccessMessage.tokenUpdateSuccess)
    case Constants.RequestName.unsuspend:
        return (232, Constants.SDKSuccessMessage.pushUnSuspendSuccess)
    case Constants.RequestName.status:
        return (233, Constants.SDKSuccessMessage.statusSuccess)
    case Constants.RequestName.pushEvent:
        return (234, Constants.SDKSuccessMessage.pushEventDelivered + (type ?? ""))
    case Constants.RequestName.mobileEvent:
        return (235, Constants.SDKSuccessMessage.mobileEventDelivered + (name ?? ""))
    default:
        return (0, "unknown request")
    }
}
