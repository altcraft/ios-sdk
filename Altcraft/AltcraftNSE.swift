//
//  AltcraftNSE.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UserNotifications

/// `AltcraftNSE` is a facade for use inside a Notification Service Extension (NSE).
///
/// It provides:
/// - push detection for Altcraft notifications;
/// - handling of incoming notification requests inside NSE;
/// - delivery of the best available content when the extension is about to expire;
/// - access to mobile event registration functions;
/// - access to profile update functions;
/// - configuration APIs for App Group and JWT provider registration.
@objcMembers
public final class AltcraftNSE: NSObject, @unchecked Sendable {

    /// The singleton instance of the AltcraftNSE class.
    public static let shared = AltcraftNSE()

    /// Provides access to the mobile event registration function.
    public let mobileEventFunctions = PublicMobileEventFunctions.shared

    /// Provides access to the profile update functions.
    public let profileFunctions = PublicProfileFunctions.shared

    /// Internal coordinator responsible for ordered SDK state mutations.
    private let stateCoordinator = SDKStateCoordinator()

    /// Internal receiver handling Altcraft push processing logic.
    private let receiver = AltcraftPushReceiver()

    private override init() {
        super.init()
    }

    // MARK: - Push Handling

    /// Determines whether the given notification request belongs to Altcraft.
    ///
    /// - Parameter request: The `UNNotificationRequest` to check.
    /// - Returns: `true` if this is an Altcraft push notification, otherwise `false`.
    public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        receiver.isAltcraftPush(request)
    }

    /// Handles an incoming Altcraft push notification request inside the Notification Service Extension.
    ///
    /// Before processing the request, this method ensures that any previously configured
    /// App Group identifier is applied.
    ///
    /// - Parameters:
    ///   - request: The `UNNotificationRequest` containing notification data.
    ///   - contentHandler: A completion handler to call with the modified notification content.
    public func handleNotificationRequest(
        request: UNNotificationRequest,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        stateCoordinator.prepareAppGroupIdentifier()
        receiver.takePush(request, withContentHandler: contentHandler)
    }

    /// Called when the Notification Service Extension is about to time out.
    ///
    /// Passes the best available content to the system.
    public func serviceExtensionTimeWillExpire() {
        receiver.serviceExtensionTimeWillExpire()
    }

    // MARK: - App Group

    /// Sets the App Group identifier and initializes the Core Data stack with it.
    ///
    /// Call this method before performing any Core Data operations if your app uses an App Group.
    /// This ensures the persistent store is correctly located in the shared container.
    ///
    /// - Parameter groupName: The App Group identifier used for the shared container.
    public func setAppGroup(groupName: String?) {
        stateCoordinator.setAppGroup(groupName)
    }

    // MARK: - JWT

    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// - Parameter provider: The `JWTInterface` implementation used to fetch JWT tokens.
    public func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
}
