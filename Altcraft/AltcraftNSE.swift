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
/// It exposes methods to detect Altcraft pushes, handle incoming notification requests,
/// and deliver the best available content on extension timeout.
@objcMembers
public class AltcraftNSE: NSObject {
    
    /// The singleton instance of the AltcraftNSE class.
    public static let shared = AltcraftNSE()

    /// Internal receiver handling Altcraft push processing logic.
    let receiver = AltcraftPushReceiver()
    
    /// Provides access to the mobile event registration function.
    public let mobileEventFunctions = PublicMobileEventFunctions.shared

    /// Determines whether the given notification request belongs to Altcraft.
    ///
    /// - Parameter request: The `UNNotificationRequest` to check.
    /// - Returns: `true` if this is an Altcraft push notification, otherwise `false`.
    public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        receiver.isAltcraftPush(request)
    }

    /// Handles an incoming Altcraft push notification request inside the Notification Service Extension.
    ///
    /// - Parameters:
    ///   - request: The `UNNotificationRequest` containing notification data.
    ///   - contentHandler: A completion handler to call with the modified notification content.
    public func handleNotificationRequest(
        request: UNNotificationRequest,
        contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        receiver.takePush(request, withContentHandler: contentHandler)
    }

    /// Called when the Notification Service Extension is about to time out.
    ///
    /// Passes the best available content to the system.
    public func serviceExtensionTimeWillExpire() {
        receiver.serviceExtensionTimeWillExpire()
    }

    /// Sets the App Group identifier and initializes the Core Data stack with it.
    ///
    /// Call this method before performing any Core Data operations if your app uses an App Group.
    /// This ensures the persistent store is correctly located in the shared container.
    ///
    /// - Parameter groupName: The App Group identifier used for the shared container.
    public func setAppGroup(groupName: String?) {
        StoredVariablesManager.shared.setGroupsName(value: groupName)
        _ = CoreDataManager(appGroup: groupName)
    }

    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// - Parameter provider: The `JWTInterface` implementation used to fetch JWT tokens.
    public func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
}
