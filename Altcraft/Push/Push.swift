//
//  Push.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Central control point for the Push module.
///
/// Mirrors the Android `com.altcraft.sdk.push.Push` `object`. Provides access to
/// push subscription, token, event, receiver and notification APIs.
///
/// Usage: `AltcraftSDK.push.token`, `AltcraftSDK.push.subscription`.
@available(iOSApplicationExtension, unavailable)
public final class Push: @unchecked Sendable {

    /// Shared Push facade instance.
    public static let shared = Push()

    private init() {}

    // MARK: - Module registration

    /// Ensures the push module is registered with the SDK.
    static func ensureRegistered() {
        // Module registration logic
    }

    // MARK: - Events

    /// Access to Push module events.
    ///
    /// Mirrors the Android `Push.moduleEvents` object member:
    /// `AltcraftSDK.push.moduleEvents.pushSubscribeRequestSuccessful`.
    ///
    /// The `PushModuleEvents` enum provides event instances as static members,
    /// so `PushModuleEvents` metatype access resolves cases directly
    /// (e.g. `moduleEvents.subscribeRequestSuccessful`).
    public var moduleEvents: PushModuleEvents.Type { PushModuleEvents.self }

    // MARK: - APIs

    /// Push token API.
    public var token: TokenAPI {
        TokenAPI.shared
    }

    /// Push event API.
    public var pushEvents: EventAPI {
        EventAPI.shared
    }

    /// Push subscription API.
    public var subscription: SubscriptionAPI {
        SubscriptionAPI.shared
    }

    /// Push notification manager.
    public var notificationManager: NotificationManager {
        NotificationManager.shared
    }
}

// MARK: - AltcraftSDK facade

/// Exposes the Push module through the unified `AltcraftSDK` entry point.
///
/// Mirrors the Android `val AltcraftSDK.push: Push get() = Push` extension property.
/// Only visible when the `AltcraftPush` module (Pod / SPM product) is linked.
@available(iOSApplicationExtension, unavailable)
public extension AltcraftSDK {

    /// Provides access to the Push module.
    ///
    /// Mirrors the Android `AltcraftSDK.push` object member.
    static var push: Push { Push.shared }
}
