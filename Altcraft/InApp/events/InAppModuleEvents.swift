//
//  InAppModuleEvents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Events belonging to the in-app module.
public enum InAppModuleEvents: String, SDKEvent {

    // MARK: - General in-app events

    case errorInAppImageLoad = "failed to load in-app image"

    // MARK: - Internal non-retryable errors

    case invalidStaticField = "invalid in-app static field"

    // MARK: - Notification errors

    case smidIsNil = "smid in the in-app data is null, it is impossible to send a in-app event to the server."

    case acidIsNil = "acid in the in-app data is null, it is impossible to send a in-app event to the server."

    // MARK: - Missing or null request payloads (retryable)

    case inAppStatusRequestDataIsNil = "in-app status request data is nil"
    case inAppEventRequestDataIsNil = "in-app event request data is nil"
    case subscribeRequestDataIsNil = "in-app subscribe request data is nil"
    case invalidSubRequestData = "invalid in-app subscribe request data"

    // MARK: - Successful API requests

    case inAppUnsubscribeRequestSuccessful = "successful request: inapp/unsubscribe"
    case inAppSubscribeRequestSuccessful = "successful request: inapp/subscribe"
    case inAppStatusRequestSuccessful = "successful request: inapp/status"
    case inAppEventRequestSuccessful = "successful request: inapp/event"
    case inAppPlacementsRequestSuccessful = "successful request: inapp/placements"

    // MARK: - Failed API requests

    case inAppUnsubscribeRequestFailed = "failed request: inapp/unsubscribe"
    case inAppPlacementsRequestFailed = "failed request: inapp/placements"
    case inAppSubscribeRequestFailed = "failed request: inapp/subscribe"
    case inAppStatusRequestFailed = "failed request: inapp/status"
    case inAppEventRequestFailed = "failed request: inapp/event"

    // MARK: - Content loading errors

    case inAppStaticErrorLoad = "error loading in-app notification static resources"
    case inAppContentErrorLoad = "error loading in-app notification content"

    // MARK: - Configuration validation

    case maxPlacementsInvalid = "Invalid in-app configuration: maxPlacements must be >= 1"
    case requestIntervalInvalid = "Invalid in-app configuration: placementsRequestInterval must be > 0"

    // MARK: - Placement count limit

    case placementsLimitExceeded = "in-app placements limit exceeded"

    public var message: String { rawValue }
}
