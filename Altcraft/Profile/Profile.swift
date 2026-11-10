//
//  Profile.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Public facade for the Profile module.
///
/// Mirrors the Android `com.altcraft.sdk.profile.Profile` `object`. Provides
/// the public API for updating profile fields.
///
/// Usage: `AltcraftSDK.profile.updateProfileFields([...])`.
@available(iOSApplicationExtension, unavailable)
public final class Profile: @unchecked Sendable {

    /// Shared Profile facade instance.
    public static let shared = Profile()

    private init() { Self.ensureRegistered() }

    // MARK: - Module registration

    /// Ensures the profile module is registered with the SDK.
    static func ensureRegistered() {
        Task { await ModuleRegistry.shared.register(ProfileModuleLifecycle.shared) }
    }

    // MARK: - Events

    /// Access to Profile module events.
    ///
    /// Mirrors the Android `Profile.moduleEvents` object member:
    /// `AltcraftSDK.profile.moduleEvents.profileUpdateRequestFailed`.
    ///
    /// The `ProfileModuleEvents` enum provides event instances as static members,
    /// so `ProfileModuleEvents` metatype access resolves cases directly
    /// (e.g. `moduleEvents.profileUpdateRequestFailed`).
    public var moduleEvents: ProfileModuleEvents.Type {
        ProfileModuleEvents.self
    }

    // MARK: - APIs

    /// Profile update API.
    public var update: UpdateAPI { UpdateAPI.shared }

    /// Updates profile fields.
    ///
    /// - Parameters:
    ///   - profileFields: Profile fields to update (optional).
    ///   - skipTriggers: Optional flag to skip triggers on the server side.
    public func updateProfileFields(
        profileFields: [String: Any?]? = nil,
        skipTriggers: Bool? = nil
    ) {
        UpdateAPI.shared.updateProfileFields(
            profileFields: profileFields,
            skipTriggers: skipTriggers
        )
    }
}

// MARK: - AltcraftSDK facade

/// Exposes the Profile module through the unified `AltcraftSDK` entry point.
///
/// Mirrors the Android `val AltcraftSDK.profile: Profile get() = Profile` extension
/// property. Only visible when the `AltcraftProfile` module (SPM product) is
/// linked.
@available(iOSApplicationExtension, unavailable)
public extension AltcraftSDK {

    /// Provides access to the Profile module.
    ///
    /// Mirrors the Android `AltcraftSDK.profile` object member.
    static var profile: Profile { Profile.shared }
}
