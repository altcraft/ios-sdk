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
    Constants.RequestName.subscribe:     (530, 430),
    Constants.RequestName.suspend:       (531, 431),
    Constants.RequestName.unsubscribe:   (532, 432),
    Constants.RequestName.tokenUpdate:   (533, 433),
    Constants.RequestName.pushEvent:     (536, 436),
    Constants.RequestName.mobileEvent:   (537, 437),
    Constants.RequestName.profileUpdate: (538, 438)
]

/// Returns both the error and success pairs for a given response and request context.
///
/// - Parameters:
///   - requestName: The logical request name (e.g., "push/subscribe").
///   - code: The HTTP status code returned by the server.
///   - response: The parsed API response object containing error details.
///   - type: Optional event type for additional context (only used for push events).
///   - name: Optional mobile event name for additional context (only used for mobile events).
/// - Returns: A tuple containing (errorPair, successPair).
internal func getRequestMessages(
    requestName: String,
    code: Int?,
    response: Response?,
    type: String?,
    name: String?
) -> (error: (Int, String), success: (Int, String)) {
    let errorPair = createErrorPair(
        requestName: requestName,
        code: code,
        response: response,
        type: type,
        name: name
    )
    let successPair = createSuccessPair(
        requestName: requestName,
        type: type,
        name: name
    )
    return (errorPair, successPair)
}

/// Returns a predefined error code and formatted error message based on the request name.
///
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
        return (434, baseMessage)

    case Constants.RequestName.status:
        return (435, baseMessage)

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
internal func createSuccessPair(
    requestName: String,
    type: String?,
    name: String?
) -> (Int, String) {
    switch requestName {
    case Constants.RequestName.subscribe:
        return (230, Constants.SDKSuccessMessage.subscribeSuccess)

    case Constants.RequestName.suspend:
        return (231, Constants.SDKSuccessMessage.suspendSuccess)

    case Constants.RequestName.unsubscribe:
        return (232, Constants.SDKSuccessMessage.unsubscribeSuccess)

    case Constants.RequestName.tokenUpdate:
        return (233, Constants.SDKSuccessMessage.tokenUpdateSuccess)

    case Constants.RequestName.unsuspend:
        return (234, Constants.SDKSuccessMessage.pushUnSuspendSuccess)

    case Constants.RequestName.status:
        return (235, Constants.SDKSuccessMessage.statusSuccess)

    case Constants.RequestName.pushEvent:
        return (236, Constants.SDKSuccessMessage.pushEventDelivered + (type ?? ""))

    case Constants.RequestName.mobileEvent:
        return (237, Constants.SDKSuccessMessage.mobileEventDelivered + (name ?? ""))
        
    case Constants.RequestName.profileUpdate:
        return (238, Constants.SDKSuccessMessage.profileUpdateSuccess)

    default:
        return (0, "unknown request")
    }
}

/// Creates a pair representing the push provider token set event.
///
/// - Parameter data: The token data containing the push provider and token string.
/// - Returns: A pair consisting of the event code and a human-readable message.
internal func createSetTokenEventPair(data: TokenData) -> (Int, String) {
    let msg = "\(pushProviderSet.1)\(data.provider) token: \(data.token)"
    return (pushProviderSet.0, msg)
}

