//
//  CoreEnvironmentProvider.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Provides Core environment instances and selected Core data to other SDK
/// modules.
///
/// A new `Environment` instance is created for each operation. Values inside
/// the environment are loaded lazily and cached only for that environment,
/// so separation is the same as in the reference platform implementation.
///
/// Only a curated set of shared data is exposed here (user tag, rToken mode,
/// application version, authentication state, internal authentication data).
/// Core configuration and external authorization data never leave Core and are
/// resolved internally by `CoreRequestBuilder` when requests are executed.
@_spi(_Altcraft) public enum CoreEnvironmentProvider {
    /// Creates a new Core environment.
    ///
    /// - Returns: A new Core environment instance.
    static func createEnvironment() -> Environment {
        Environment.create()
    }

    /// Returns the current user tag.
    ///
    /// A temporary Core environment is created for this request.
    ///
    /// - Returns: The current user tag.
    public static func userTag() async throws -> String {
        try await createEnvironment().userTag()
    }

    /// Throws when the Core module or the given module is in a critical
    /// Core Data error state.
    ///
    /// Modules check this before interacting with persistent storage so a
    /// broken database is surfaced as an SDK error instead of a crash.
    ///
    /// Module flags are isolated: a broken store of one module limits only
    /// that module's operations. The Core module's flag is checked for every
    /// module, because all of them depend on Core's configuration and
    /// authentication data.
    ///
    /// - Parameter module: Calling module's model name (e.g. "Push").
    public static func checkDbError(module: String) throws {
        let storage = StoredVariablesManager.shared

        if storage.getDbErrorStatus()
            || storage.getDbErrorStatus(module: module) {
            throw ExceptionExtension.exception(CoreEvents.coreDataError)
        }
    }

    /// Throws when the Core module is in a critical Core Data error state.
    ///
    /// Core-scoped legacy entry point: equivalent to
    /// `checkDbError(module:)` with the Core module name.
    public static func checkDbError() throws {
        try checkDbError(module: Constants.CoreData.coreModelName)
    }

    /// Returns whether rToken-based authentication is in use.
    ///
    /// - Returns: `true` if the SDK configuration defines an rToken.
    public static func usesRToken() async throws -> Bool {
        guard let rToken = try await createEnvironment().config().rToken else {
            return false
        }
        return !rToken.isEmpty
    }

    /// Returns whether a role token exists in the system.
    ///
    /// Unlike ``usesRToken()``, the check also covers a role token obtained
    /// from the JWT payload (Android parity, `CoreEnvironmentProvider.existRToken`).
    ///
    /// - Returns: `true` if a role token exists; `false` otherwise.
    public static func existRToken() async -> Bool {
        let config = try? await createEnvironment().config()

        if config?.rToken != nil {
            return true
        }

        return extractRToken(jwt: JWTManager.shared.getJWT()) != nil
    }

    /// Returns the current application version from the SDK configuration.
    ///
    /// - Returns: The current application version, or `nil` if it is not set.
    public static func appVersion() async throws -> String? {
        try await createEnvironment().config().appInfo?.appVer
    }

    /// Checks whether the current profile is authenticated.
    ///
    /// A temporary Core environment is created for this request.
    ///
    /// - Returns: `true` if the current user tag matches the stored
    ///   authentication state; otherwise `false`.
    public static func isAuth() async -> Bool {
        await Authenticate().isAuthenticated(env: createEnvironment())
    }

    /// Returns the internal authentication state.
    ///
    /// A temporary Core environment is created for this request.
    ///
    /// - Returns: The current internal authentication data.
    public static func internalAuth() async throws -> InternalAuthData {
        try await createEnvironment().internalAuth()
    }
}
