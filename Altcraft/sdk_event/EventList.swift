//
//  EventList.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

// 200 — General SDK events
let configSet = (200, "SDK configuration is installed.")
let pushProviderSet = (201, "push provider set: ")
let pushReceive = (203, "received Altcraft push notification.")
let pushIsPosted = (204, "push is posted.")
let sdkCleared = (205, "SDK data has been cleared")
let backgroundTaskRegister = (206, "SDK background task is registered")
let backgroundTaskСompleted = (207, "SDK background task completed")

/// 230–235 — Success codes for completed server requests:
/// - 230 → subscribe request succeeded
/// - 231 → token update request succeeded
/// - 232 → unsuspend request succeeded
/// - 233 → status request succeeded
/// - 234 → push event delivered successfully
/// - 235 → mobile event delivered successfully

// 400 — used for error, after which the operation cannot be repeated.

// Common internal error
let configIsNotSet = (401, "the configuration is not set")
let userTagIsNilE = (402, "userTag is null. It is impossible to identify the user")
let coreDataError = (403, "error in CoreData. Re-initialize the SDK.")
let errorLoadModelInCoreData = (404, "failed to load model from framework.")
let appGroupIsNotSet = (405, "App Group name was not set.")
let apnsIsNotUpdated = (406, "Forcing a push token update is not possible: the operation is not supported for APNs.")
let longWaitConfigInstall = (407, "long wait for configuration installation > 5s")
let invalidCoreDataEntityName = (408, "the coreData entity name is not valid")

// Invalid value
let invalidUrlValue = (471, "invalid apiUrl value - empty or null.")
let invalidRTokenValue = (472, "invalid resourse token value - resourse token is empty.")
let invalidPushProviders = (473, "invalid provider. Available - ios-apns, ios-firebase, android-huawei.")
let nonJsonObject = (474, "non-json object has been provided")
let fieldsIsObjects = (475, "invalid values: not all values are primitives")
let unsupportedSubscriptionType = (476, "unsupported subscription type. Available: EmailSubscription, SmsSubscription, PushSubscription, CcDataSubscription")

// Notification error
let errorHandleUserInfo = (450, "invalid userInfo format")
let uidIsNil = (451, "uid in the push data is null, it is impossible to send a push event to the server.")
let errorMediaDownload = (452, "could not download image data from URL.")
let errorMediaKeyMissing = (453, "'media' key is missing or URL string is invalid.")
let errorButtonsKeyMissing = (454, "'buttons' key is missing or is invalid.")
let invalidButtonIdentifier = (455, "invalid button identifier. See event value")
let outOfRangeForIdentifier = (456, "out of range for identifier. See event value")
let unknownButtonIdentifier = (457, "unknown button identifier. See event value")

/// 423–424 — Missing request payloads (no automatic retry)
/// These errors indicate missing request data for which the SDK does not attempt to recollect
/// or retry.
let unSuspendRequestDataIsNil = (422, "unsuspend request data is nil")
let profileRequestDataIsNil = (423, "profile request data is nil")

/// 430–435 — SDK-to-server request errors without automatic retry
/// - 430 → subscribe request failed
/// - 431 → token update request failed
/// - 432 → unsuspend request failed
/// - 433 → status request failed
/// - 434 → push event delivery failed
/// - 435 → mobile event delivery failed

// 500 — used for error, after which the operation should be retried automatically

// 501–506 — Missing SDK state or environment issues
let configIsNil  = (501, "config data is nil")
let currentTokenIsNil  = (502, "current token is is nil")
let userTagIsNil = (503, "userTag is null. It is impossible to identify the user")
let permissionDenied = (504, "notification permission denied.")
let sdkIsNotInit = (505, "sdk is not initialized. Automatic repeat of the check after a while.")
let backgroundTaskExpired = (506, "SDK background task expired")

/// 520–529 — Missing or null request payloads
/// These indicate that required data for a request is not available at the time of execution.
/// The SDK will attempt to collect and resend the data automatically.
let commonDataIsNil = (529, "common data is nil")
let subscribeRequestDataIsNil = (520, "subscribe request data is nil")
let updateRequestDataIsNil = (521, "update request data is nil")
let pushEventRequestDataIsNil = (524, "push event request data is nil")
let mobileRequestDataIsNil = (525, "mobile event request data is nil")

/// 530–535 — SDK-to-server request errors with automatic retry by the SDK
/// - 530 → subscribe request failed (retryable)
/// - 531 → token update request failed (retryable)
/// - 534 → push event delivery failed (retryable)
/// - 535 → mobile event delivery failed (retryable)

// 540–544 — Authorization-related errors
let jwtIsNil = (540, "JWT token is nil")
let JWTParsingError = (541, "JWT parsing error")
// 542 — invalidMatching
let authDataIsNil  = (543, "auth data is nil")

// Request / response error
let failedCreateRequest = (561, "Failed to create request.")
let failedProcessingResponse  = (562, "Failed processing the response")
    
// invalid values
let invalidRequestUrl = (571, "invalid request url")
let invalidResponseFormat = (572, "invalid response format")
let invalidSubscribeRequestData = (573, "invalid push subscribe request data")
let invalidPushEventRequestData = (574, "invalid push event request data")

