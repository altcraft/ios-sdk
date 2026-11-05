//
//  AltcraftModule.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Defines lifecycle callbacks for an optional Altcraft SDK module.
///
/// Optional modules register an implementation of this protocol in
/// ``ModuleRegistry`` and receive SDK initialization and cleanup events.
@_spi(_Altcraft) public protocol AltcraftModule: QueueWorker, Sendable {
    /// Unique module identifier.
    ///
    /// The identifier is used to prevent duplicate module registration.
    var moduleId: String { get }

    /// Called after Altcraft SDK core initialization has completed successfully.
    ///
    /// The module processes its pending queue without scheduling local retries,
    /// matching the SDK initialization phase.
    func onSdkInitialized() async

    /// Called when Altcraft SDK data is being cleared.
    ///
    /// The module must stop its background work and clean up its persisted data.
    func onSdkClear() async

    /// Called when the SDK rToken changes.
    ///
    /// The module should clean up data that is bound to the previous rToken.
    func onSdkRTokenChanged() async

    /// Called when the authentication state changes (e.g., user logout).
    ///
    /// The module should drop pending data bound to the previous ACID.
    func onAuthStateChanged() async

    /// Called when the process environment is reset (e.g., a Notification
    /// Service Extension starts a new delivery in a reused process).
    ///
    /// The module must drop per-process cached state that is derived from
    /// the SDK configuration, so subsequent reads observe the current
    /// persistent configuration.
    func onEnvironmentReset() async

    /// Validates this module configuration.
    ///
    /// Called before ``configure(_:)`` to ensure that the provided
    /// configuration contains valid values required by this module.
    ///
    /// - Parameter configuration: Configuration of this module to validate.
    /// - Returns: `true` when the configuration is valid and may be applied
    ///   through ``configure(_:)``; `false` when the configuration is invalid
    ///   and must not be persisted.
    func validate(_ configuration: any ModuleConfiguration) async -> Bool

    /// Persists and applies this module configuration.
    ///
    /// Called only for modules whose configuration is present and has passed
    /// ``validate(_:)``.
    ///
    /// - Parameter configuration: Configuration of this module.
    func configure(_ configuration: any ModuleConfiguration) async
}

@_spi(_Altcraft) public extension AltcraftModule {
    /// Default implementation treats any configuration as valid.
    func validate(_ configuration: any ModuleConfiguration) async -> Bool { true }

    /// Default implementation does nothing.
    func onSdkRTokenChanged() async {}

    /// Default implementation does nothing.
    func onAuthStateChanged() async {}

    /// Default implementation does nothing.
    func onEnvironmentReset() async {}

    /// Default implementation does nothing.
    func configure(_ configuration: any ModuleConfiguration) async {}
}

/// Runtime entry point supplied by linked modules without configuration.
@_spi(_Altcraft) public protocol LinkedModuleProvider {
    static var lifecycle: any AltcraftModule { get }
}
