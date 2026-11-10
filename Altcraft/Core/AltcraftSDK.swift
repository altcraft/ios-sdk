//
//  AltcraftSDK.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A singleton class that initializes and exposes public modules of the Altcraft SDK.
///
/// `AltcraftSDK` is the primary entry point for the Altcraft platform.
/// It provides the core capabilities and acts as the aggregation point for all
/// module-specific public APIs:
/// - sdkEvents: Managing and observing SDK-level events.
/// - auth: Authentication / logout APIs.
/// - backgroundTasks: Scheduling and handling periodic background tasks.
/// - push: Push module facade. **(AltcraftPush)**
/// - inApp: In-App module facade. **(AltcraftInApp)**
/// - profile: Profile module facade. **(AltcraftProfile)**
/// - target: Target module facade. **(AltcraftTarget)**
///
/// Mirrors the Android `AltcraftSDK` object: all members are accessed
/// statically (`AltcraftSDK.push`, `AltcraftSDK.initialization(configuration:)`)
/// without a `shared` qualifier.
///
/// Module-specific properties are added by each module through `public extension AltcraftSDK`,
/// so they are only visible when the corresponding module is linked. The facade itself
/// lives in `AltcraftCore` so every consumer of the SDK always has a single, well-known entry point.
@objcMembers
@available(iOSApplicationExtension, unavailable)
public final class AltcraftSDK: NSObject, @unchecked Sendable {

    /// The singleton instance of the AltcraftSDK class.
    public static let shared = AltcraftSDK()

    private override init() {
        super.init()
    }

    // MARK: - Core modules (always available)

    /// Provides access to SDK events (subscription management and core events).
    ///
    /// Mirrors Android `AltcraftSDK.sdkEvents`.
    public static var sdkEvents: SDKEvents { SDKEvents.shared }

    /// Provides access to auth functions.
    public static var auth: AuthAPI { AuthAPI.shared }

    /// Provides access to background task registration.
    public static var backgroundTasks: BackgroundTask { BackgroundTask.shared }

    // MARK: - Initialization

    /// Initializes the SDK with the provided configuration.
    ///
    /// This method guarantees that any previously completed `setAppGroup(groupName:)`
    /// call is fully applied before SDK initialization starts.
    ///
    /// - Parameters:
    ///   - configuration: An `AltcraftConfiguration` object containing configuration details.
    ///   - completion: Optional callback invoked on the main actor:
    ///     `true` on success, `false` on failure.
    public static func initialization(
        configuration: AltcraftConfiguration,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) {
        Task {
            SDKStateCoordinator.shared.prepareAppGroupIdentifier()

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
    public static func clear(completion: (() -> Void)? = nil) {
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
    public static func setAppGroup(groupName: String?) {
        SDKStateCoordinator.shared.setAppGroup(
            groupName
        )
    }
}
