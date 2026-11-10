//
//  Target.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Public facade for the Target (mobile-event) module.
///
/// Mirrors the Android `com.altcraft.sdk.target.Target` `object`. Provides the
/// public API for sending target (mobile) events to the server.
///
/// Usage: `AltcraftSDK.target.sendTarget(sid: "x", eventName: "click")`.
@available(iOSApplicationExtension, unavailable)
public final class Target: @unchecked Sendable {

    /// Shared Target facade instance.
    public static let shared = Target()

    private init() { Self.ensureRegistered() }

    // MARK: - Module registration

    /// Ensures the target module is registered with the SDK.
    static func ensureRegistered() {
        Task { await ModuleRegistry.shared.register(TargetModuleLifecycle.shared) }
    }

    // MARK: - Events

    /// Access to Target module events.
    ///
    /// Mirrors the Android `Target.moduleEvents` object member:
    /// `AltcraftSDK.target.moduleEvents.mobileEventRequestFailed`.
    ///
    /// The `TargetModuleEvents` enum provides event instances as static members,
    /// so `TargetModuleEvents` metatype access resolves cases directly
    /// (e.g. `moduleEvents.mobileEventRequestFailed`).
    public var moduleEvents: TargetModuleEvents.Type { TargetModuleEvents.self }

    // MARK: - APIs

    /// Target (mobile event) API.
    public var target: TargetAPI { TargetAPI.shared }

    /// Sends a target (mobile) event to the server.
    ///
    /// - Parameters:
    ///   - sid: The string ID of the pixel.
    ///   - altcraftClientID: Optional Altcraft client id (defaults to `""`).
    ///   - eventName: Event name.
    ///   - sendMessageId: Message identifier to link the event.
    ///   - payload: Event payload data.
    ///   - matching: Matching parameters.
    ///   - matchingType: Matching mode or type.
    ///   - profileFields: Profile fields.
    ///   - subscription: Subscription attached to the profile.
    ///   - utm: UTM tags used for attribution.
    public func sendTarget(
        sid: String,
        altcraftClientID: String = "",
        eventName: String,
        sendMessageId: String? = nil,
        payload: [String: Any?]? = nil,
        matching: [String: Any?]? = nil,
        matchingType: String? = nil,
        profileFields: [String: Any?]? = nil,
        subscription: (any Subscription)? = nil,
        utm: UTM? = nil
    ) {
        TargetAPI.shared.sendTarget(
            sid: sid,
            altcraftClientID: altcraftClientID,
            eventName: eventName,
            sendMessageId: sendMessageId,
            payload: payload,
            matching: matching,
            matchingType: matchingType,
            profileFields: profileFields,
            subscription: subscription,
            utm: utm
        )
    }
}

// MARK: - AltcraftSDK facade

/// Exposes the Target module through the unified `AltcraftSDK` entry point.
///
/// Mirrors the Android `val AltcraftSDK.target: Target get() = Target` extension
/// property. Only visible when the `AltcraftTarget` module (SPM product) is
/// linked.
@available(iOSApplicationExtension, unavailable)
public extension AltcraftSDK {

    /// Provides access to the Target module.
    ///
    /// Mirrors the Android `AltcraftSDK.target` object member.
    static var target: Target { Target.shared }
}
