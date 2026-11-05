//
//  ConfigManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Manages SDK configuration access with caching.
///
/// Holds a cached ``Configuration`` on top of ``CoreConfigDao``,
/// which owns all Core Data access.
///
/// The actor isolation serializes `setConfig`/`getConfig`, so a cache
/// reset never races with a concurrent cache load.
actor ConfigManager {

    /// Shared instance.
    static let shared = ConfigManager()

    /// Thread-safe async cache for the SDK configuration.
    private let configLazy = AsyncLazy<Configuration?>()

    /// Data access for the SDK configuration.
    private let dao = CoreConfigDao()

    private init() {}

    /// Validates the SDK configuration.
    ///
    /// When the configuration is invalid, the stored configuration entity
    /// is deleted and the setup error is emitted from the configuration
    /// itself.
    ///
    /// - Parameter config: The SDK configuration to validate.
    /// - Returns: `true` when the configuration is valid, otherwise `false`.
    func validateConfig(_ config: AltcraftConfiguration) async -> Bool {
        guard config.valid else {
            await dao.delete()
            config.error()
            return false
        }
        return true
    }

    /// Saves the SDK configuration, invalidating the cache first.
    ///
    /// The configuration is validated before saving. When the configuration
    /// is invalid, the stored configuration entity is deleted, and the setup
    /// error is emitted from the configuration itself.
    ///
    /// Mirrors Android `ConfigManager.validateConfig` + `setConfig`.
    ///
    /// - Parameter config: The SDK configuration to install.
    /// - Returns: `true` on success, `false` on failure.
    func setConfig(_ config: AltcraftConfiguration) async -> Bool {
        await configLazy.reset()

        guard await validateConfig(config) else {
            return false
        }

        return await dao.save(
            url: config.getApiUrl(),
            rToken: config.getRToken(),
            appInfo: config.getAppInfo()
        )
    }

    /// Returns the cached SDK configuration.
    ///
    /// - Returns: The cached configuration, or `nil` when none is stored.
    func getConfig() async -> Configuration? {
        do {
            return try await configLazy.get {
                await self.dao.fetch()
            } ?? nil
        } catch {
            return nil
        }
    }

    /// Clears the cached configuration.
    ///
    /// The next ``getConfig()`` call reloads the configuration from the DAO.
    func clearCache() async {
        await configLazy.reset()
    }
}
