//
//  AltcraftNSE+Push.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

@preconcurrency import UserNotifications
import Foundation
@_spi(_Altcraft) import AltcraftCore

private let pushReceiver = AltcraftPushReceiver()

/// Push-specific NSE APIs.
///
/// Available when the `AltcraftPush` module (SPM product) is present.
public extension AltcraftNSE {

    /// Determines whether the given notification request belongs to Altcraft.
    ///
    /// - Parameter request: The `UNNotificationRequest` to check.
    /// - Returns: `true` if this is an Altcraft push notification, otherwise
    ///   `false`.
    static func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        pushReceiver.isAltcraftPush(request)
    }

    /// Handles an incoming Altcraft push notification request inside the
    /// Notification Service Extension.
    ///
    /// Before processing the request, this method ensures that any previously
    /// configured App Group identifier is applied.
    ///
    /// - Parameters:
    ///   - request: The `UNNotificationRequest` containing notification data.
    ///   - contentHandler: A completion handler to call with the modified
    ///     notification content.
    static func handleNotificationRequest(
        request: UNNotificationRequest,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        SDKStateCoordinator.shared.prepareAppGroupIdentifier()
        pushReceiver.takePush(request, withContentHandler: contentHandler)
    }

    /// Called when the Notification Service Extension is about to time out.
    ///
    /// Passes the best available content to the system.
    static func serviceExtensionTimeWillExpire() {
        pushReceiver.serviceExtensionTimeWillExpire()
    }
}
