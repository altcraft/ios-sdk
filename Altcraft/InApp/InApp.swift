//
//  InApp.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Public facade for the In-App module.
///
/// Mirrors the Android `com.altcraft.sdk.inapp.InApp` `object`. All public
/// In-App APIs (screen tracking, triggers, placements, animations, subscription)
/// are exposed through this single entry point.
///
/// Usage: `AltcraftSDK.inApp.setScreen("home")`.
@available(iOSApplicationExtension, unavailable)
public final class InApp: @unchecked Sendable {

    /// Shared In-App facade instance.
    public static let shared = InApp()

    private init() {}

    // MARK: - Module registration

    /// Ensures the in-app module is registered with the SDK.
    static func ensureRegistered() {
        // Module registration logic
    }

    // MARK: - Events

    /// Access to In-App module events.
    ///
    /// Mirrors the Android `InApp.moduleEvents` object member:
    /// `AltcraftSDK.inApp.moduleEvents.maxPlacementsInvalid`.
    ///
    /// The `InAppModuleEvents` enum provides event instances as static members,
    /// so `InAppModuleEvents` metatype access resolves cases directly
    /// (e.g. `moduleEvents.maxPlacementsInvalid`).
    public var moduleEvents: InAppModuleEvents.Type { InAppModuleEvents.self }

    // MARK: - Subscription

    /// Provides access to In-App subscription management.
    ///
    /// The implementation lives inside the `platform/subscription/subscribe`
    /// feature so that subscription logic stays with the feature it belongs to.
    public var subscription: SubscribeAPI { SubscribeAPI.shared }

    // MARK: - Screen

    /// Sets the current screen used for In-App placement matching.
    ///
    /// - Parameter screen: Screen identifier used to match available In-App campaigns.
    public func setScreen(screen: String) {
        InAppVariables.shared.setCurrentScreen(screen)
    }

    // MARK: - Triggers

    /// Triggers processing of In-App campaigns associated with the given trigger.
    ///
    /// - Parameter name: In-App event used as a custom trigger.
    public func trigger(name: String) {
        InAppProcTrigger.trigger(
            InAppModel.InAppTrigger(name: name, type: .custom)
        )
    }

    // MARK: - Placements

    /// Requests available In-App placements from the backend.
    ///
    /// Forces a user-initiated placements request regardless of automatic
    /// request configuration and request timeout.
    public func getPlacements() {
        Task {
            await InAppPlacementsProcess.shared.requestPlacements(userReq: true)
        }
    }

    // MARK: - JSON content

    /// Provides access to JSON-content in-app subscription.
    ///
    /// Mirrors the Android `JsonContentAPI` object:
    /// `AltcraftSDK.inApp.jsonContent.subscribe { json in ... }`.
    public var jsonContent: JsonContentAPI { JsonContentAPI.shared }

    // MARK: - Lifecycle

    /// Registers SDK lifecycle observers used by in-app flows.
    ///
    /// Safe to call multiple times.
    public func registerLifecycleTracking() {
        AppLifecycleTracker.shared.register()
    }

    // MARK: - Animation

    /// Sets animation hook for the in-app view.
    ///
    /// The block is called after the in-app page is loaded and static resources
    /// are injected.
    ///
    /// - Parameter block: Animation configuration block applied to the shown animator.
    public func animation(_ block: @escaping @MainActor (InAppAnimator) -> Void) {
        Task {
            await InAppAnimationRegistry.shared.setListener(block)
        }
    }
}

// MARK: - AltcraftSDK facade

/// Exposes the In-App module through the unified `AltcraftSDK` entry point.
///
/// Mirrors the Android `val AltcraftSDK.inApp: InApp get() = InApp` extension property.
/// Only visible when the `AltcraftInApp` module (Pod / SPM product) is linked.
@available(iOSApplicationExtension, unavailable)
public extension AltcraftSDK {

    /// Provides access to the In-App module.
    ///
    /// Mirrors the Android `AltcraftSDK.inApp` object member.
    static var inApp: InApp { InApp.shared }
}
