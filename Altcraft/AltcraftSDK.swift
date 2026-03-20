//
//  AltcraftSDK.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton class that initializes and exposes public modules of the Altcraft SDK.
///
/// AltcraftSDK is the primary entry point for the Altcraft platform.
/// It provides:
/// - eventSDKFunctions: Managing and observing SDK-level events.
/// - pushTokenFunctions: Setting and managing push token providers (APNs, FCM, HMS).
/// - pushSubscriptionFunctions: Submitting and managing push subscription requests.
/// - pushEventFunctions: Manual registration of push notification events.
/// - mobileEventFunctions: Registration of generic mobile events (non-push), incl. payload/matching/UTM.
/// - profileFunctions: Updating profile fields.
/// - backgroundTasks: Scheduling and handling periodic background tasks.
/// - notificationManager: Handling notification behavior in foreground/background.
///
/// It also exposes configuration and cleanup APIs for initializing and resetting the SDK.
@objcMembers
@available(iOSApplicationExtension, unavailable)
public final class AltcraftSDK: NSObject, @unchecked Sendable {

    /// The singleton instance of the AltcraftSDK class.
    public static let shared = AltcraftSDK()

    /// Provides access to SDK events.
    public let eventSDKFunctions = SDKEvents.shared

    /// Provides access to push token-related functions.
    public let pushTokenFunctions = PublicPushTokenFunctions.shared

    /// Provides access to push subscription functions.
    public let pushSubscriptionFunctions = PublicPushSubscriptionFunctions.shared

    /// Provides access to the push event registration functions.
    public let pushEventFunctions = PublicPushEventFunctions.shared

    /// Provides access to the mobile event registration functions.
    public let mobileEventFunctions = PublicMobileEventFunctions.shared

    /// Provides access to the profile update functions.
    public let profileFunctions = PublicProfileFunctions.shared

    /// Provides access to background task registration.
    public let backgroundTasks = BackgroundTask.shared

    /// Provides access to push notification processing functions.
    public let notificationManager = NotificationManager.shared

    /// Internal coordinator responsible for ordered SDK state mutations.
    private let stateCoordinator = SDKStateCoordinator()

    private override init() {
        super.init()
    }

    // MARK: - Initialization

    /// Initializes the SDK with the provided configuration.
    ///
    /// This method guarantees that any previously completed setAppGroup(groupName:)
    /// call is fully applied before SDK initialization starts.
    ///
    /// - Parameters:
    ///   - configuration: An optional AltcraftConfiguration object containing configuration details.
    ///   - completion: Optional callback invoked on the main actor:
    ///     true on success, false on failure.
    public func initialization(
        configuration: AltcraftConfiguration?,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        Task {
            stateCoordinator.prepareAppGroupIdentifier()

            let result = await AltcraftInit.shared.initSDK(
                configuration: configuration
            )

            await MainActor.run {
                completion?(result)
            }
        }
    }
    
    // MARK: - Cleanup

    /// Clears SDK data and invokes the completion after cleanup finishes.
    ///
    /// - Parameter completion: Optional closure called after cleanup is finished.
    public func clear(completion: (() -> Void)? = nil) {
        clearCache {
            completion?()
        }
    }

    // MARK: - App Group

    /// Sets the App Group identifier and initializes the Core Data stack with it.
    ///
    /// Call this method before SDK initialization if you use an App Group.
    /// This ensures the persistent store is correctly located in the shared container.
    ///
    /// This method is synchronous and returns only after the App Group setup
    /// has been applied on the internal serial queue.
    ///
    /// - Parameter groupName: App Group identifier used for the shared container.
    public func setAppGroup(groupName: String?) {
        stateCoordinator.setAppGroup(groupName)
    }

    // MARK: - JWT

    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// - Parameter provider: The JWTInterface implementation used to fetch JWT tokens.
    public func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
}
