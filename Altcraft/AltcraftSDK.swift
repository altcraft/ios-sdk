//
//  AltcraftSDK.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit
import Network

/// A singleton class that manages initialization and provides access to public modules of the Altcraft SDK.
///
/// `AltcraftSDK` acts as the primary entry point for integrating with the Altcraft platform. It exposes interfaces for:
/// - `events`: Managing and observing SDK events.
/// - `pushTokenFunction`: Setting and managing push token providers (FCM, HMS, APNs).
/// - `pushSubscriptionFunctions`: Submitting and managing push subscription requests.
/// - `pushEventFunctions`: Manual registration of push notification events.
/// - `periodicBackgroundTasks`: Scheduling and handling periodic background tasks.
/// - `notificationManager`: Handling foreground/background notification behavior.
///
/// It also provides configuration and cleanup APIs for initializing and resetting the SDK.
@objcMembers
public class AltcraftSDK: NSObject {

    /// The singleton instance of the `Altcraft` class.
    public static let shared = AltcraftSDK()
    
    /// Provides access to SDK events.
    public let eventSDKFunctions = SDKEvents.shared

    /// Provides access to push token-related functions.
    public let pushTokenFunction = PublicPushTokenFunctions.shared

    /// Provides access to push subscription functions.
    public let pushSubscriptionFunctions = PublicPushSubscriptionFunctions.shared
    
    /// Provides access to the push event registration function
    public let pushEventFunctions = PublicPushEventFunctions.shared
    
    /// Provides access to the mobile event registration function
    public let mobileEventFunctions = PublicMobileEventFunctions.shared

    /// Provides access to background task registration.
    public let backgroundTasks = BackgroundTask.shared

    /// Provides access to push notification processing functions.
    public let notificationManager = NotificationManager.shared
    
    /// Initializes the Altcraft SDK with the provided configuration.
    ///
    /// This method configures the framework using the provided `AltcraftConfiguration` object.
    /// If the configuration is `nil`, the method will return without performing any actions.
    /// - Parameters:
    ///   - configuration: An optional `AltcraftConfiguration` object containing configuration details.
    ///   - completion: Optional callback (on main queue): `true` on success, `false` on failure.
    public func initialization(
        configuration: AltcraftConfiguration?,
        completion: ((Bool) -> Void)? = nil
    ) {
        AltcraftInit.shared.initSDK(configuration: configuration, completion: completion)
    }
    
    /// Sets the App Group identifier and initializes the Core Data stack with it.
    ///
    /// Call this method before performing any Core Data operations if you use an App Group.
    /// This ensures the persistent store is correctly located in the shared container.
    ///
    /// - Parameter groupName: The App Group ID  used to access the shared container.
    ///
    public func setAppGroup(groupName: String) {
        StoredVariablesManager.shared.setGroupsName(value: groupName)
        
        _ = CoreDataManager(appGroup: groupName)
    }
    
    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// - Parameter provider: The `JWTInterface` implementation used to fetch JWT tokens.
    public func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
    
    /// Public function to clear SDK data and trigger the completion after cleanup.
    ///
    /// - Parameter completion: Optional closure to be called after cleanup is finished.
    public func clear(completion: (() -> Void)? = nil) {
        clearCache {
            completion?()
        }
    }
}
