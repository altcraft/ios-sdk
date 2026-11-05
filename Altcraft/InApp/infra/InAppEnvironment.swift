//
//  InAppEnvironment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Provides dependencies required by the In-App module.
///
/// Shared SDK data is requested through `CoreEnvironmentProvider`; module
/// configuration comes from the in-app module itself.
struct InAppEnvironment {

    /// Returns a freshly created in-app environment for an operation.
    ///
    /// Each call produces an independent (uncached) environment.
    static func fresh() -> InAppEnvironment {
        InAppEnvironment()
    }

    private init() {}

    /// Throws if the Core or In-App module Core Data is in critical error state.
    ///
    /// The In-App module's failure is isolated: it limits only in-app
    /// operations, the Core flag additionally covers Core's shared data.
    func checkCoreDataError() throws {
        try CoreEnvironmentProvider.checkDbError(
            module: InAppConstants.CoreData.modelName
        )
    }

    /// Returns the stored in-app module configuration.
    ///
    /// - Returns: The stored in-app configuration, or the default configuration
    ///   when none has been saved yet.
    func config() async -> InAppConfiguration {
        await InAppConfigManager.shared.getConfig()
    }

    /// Returns the current application version from the SDK configuration.
    ///
    /// - Returns: Current application version, or `nil` if it is not set.
    func appVersion() async throws -> String? {
        try await CoreEnvironmentProvider.appVersion()
    }

    /// Returns the internal authentication state.
    ///
    /// - Returns: Current internal authentication data.
    func internalAuth() async throws -> InternalAuthData {
        try await CoreEnvironmentProvider.internalAuth()
    }

    /// Returns the current user tag.
    ///
    /// - Returns: Current user tag.
    func userTag() async throws -> String {
        try await CoreEnvironmentProvider.userTag()
    }
}
