//
//  PushModuleEvents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Events belonging to the push module.
public enum PushModuleEvents: String, SDKEvent {

    // MARK: - General push events

    case pushProviderSet = "push provider set: "
    case pushReceive = "received Altcraft push notification."
    case pushIsPosted = "push is posted."
    case duplicatePushMessage = "duplicate push message, uid: "
    case pushTokenUpdateAwait = "waiting for push token update to complete"

    // MARK: - Internal non-retryable errors

    case apnsIsNotUpdated = "forcing a push token update is not possible: the operation is not supported for APNs."

    // MARK: - Notification errors

    case errorHandleUserInfo = "invalid userInfo format"
    case uidIsNil = "uid in the push data is null, it is impossible to send a push event to the server."
    case errorMediaDownload = "could not download image data from URL."
    case errorMediaKeyMissing = "'media' key is missing or URL string is invalid."
    case errorButtonsKeyMissing = "'buttons' key is missing or is invalid."
    case invalidButtonIdentifier = "invalid button identifier. See event value"
    case outOfRangeForIdentifier = "out of range for identifier. See event value"
    case unknownButtonIdentifier = "unknown button identifier. See event value"

    // MARK: - Invalid values

    case invalidPushProviders = "invalid provider. Available - ios-apns, ios-firebase, ios-huawei."
    case invalidPushProvider = "invalid provider."

    // MARK: - Missing SDK state or environment issues

    case pushTokenIsNil = "current push token is nil"

    // MARK: - Missing or null request payloads (retryable)

    case subscribeRequestDataIsNil = "subscribe request data is nil"
    case updateRequestDataIsNil = "update request data is nil"
    case pushEventRequestDataIsNil = "push event request data is nil"
    case unsuspendRequestDataIsNil = "unsuspend request data is nil"
    case pushStatusRequestDataIsNil = "push status request data is nil"

    // MARK: - Invalid request / response values

    case invalidSubRequestData = "invalid push subscribe request data"
    case invalidPushEventRequestData = "invalid push event request data"

    // MARK: - Push configuration persistence

    case pushConfigurationSaveFailed = "failed to save the push configuration to the local database"
    case pushConfigurationClearFailed = "failed to clear the push configuration from the local database"

    // MARK: - Successful API requests

    case pushUnsubscribeRequestSuccessful = "successful request: push/unsubscribe"
    case pushSubscribeRequestSuccessful = "successful request: push/subscribe"
    case pushSuspendRequestSuccessful = "successful request: push/suspend"
    case pushStatusRequestSuccessful = "successful request: push/status"
    case tokenUpdateRequestSuccessful = "successful request: push/update"
    case pushEventRequestSuccessful = "successful request: event/push"
    case unsuspendRequestSuccessful = "successful request: push/unsuspend"

    // MARK: - Failed API requests

    case pushUnsubscribeRequestFailed = "failed request: push/unsubscribe"
    case pushSubscribeRequestFailed = "failed request: push/subscribe"
    case pushSuspendRequestFailed = "failed request: push/suspend"
    case pushStatusRequestFailed = "failed request: push/status"
    case tokenUpdateRequestFailed = "failed request: push/update"
    case pushEventRequestFailed = "failed request: event/push"
    case unsuspendRequestFailed = "failed request: push/unsuspend"

    public var message: String { rawValue }
}
