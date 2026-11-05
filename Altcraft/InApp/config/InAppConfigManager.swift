//
//  InAppConfigManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Manages and caches the in-app module configuration.
///
/// Provides cached access to ``InAppConfiguration`` while persistence
/// is handled by ``InAppConfigDao``.
///
/// The actor isolation serializes `setConfig`/`getConfig`, so a cache
/// reset never races with a concurrent cache load.
actor InAppConfigManager {

    /// Shared instance.
    static let shared = InAppConfigManager()

    /// Thread-safe async cache for the in-app configuration.
    private let configLazy = AsyncLazy<InAppConfiguration>()

    /// Data access for the in-app configuration.
    private let dao = InAppConfigDao()

    private init() {}

    /// Returns the stored in-app module configuration.
    ///
    /// Returns the default configuration when no stored configuration exists.
    func getConfig() async -> InAppConfiguration {
        (try? await configLazy.get {
            await self.dao.get()
        }) ?? InAppConfiguration()
    }

    /// Validates the in-app module configuration.
    ///
    /// When the configuration is invalid, it is removed from persistence
    /// and the in-app module emits the corresponding `SDKEvent`.
    ///
    /// Mirrors Android `ConfigManager.validateConfig`.
    ///
    /// - Parameter config: In-app module configuration to validate.
    /// - Returns: `true` when the configuration is valid, otherwise `false`.
    func validateConfig(_ config: InAppConfiguration) async -> Bool {
        guard config.valid else {
            await clearCache()
            config.error()
            return false
        }
        return true
    }

    /// Saves the in-app module configuration, invalidating the cache first.
    ///
    /// - Parameter config: In-app module configuration to save.
    func setConfig(_ config: InAppConfiguration) async {
        await configLazy.reset()
        await dao.set(config)
    }

    /// Clears the stored in-app module configuration, invalidating the cache first.
    func clearCache() async {
        await configLazy.reset()
        await dao.delete()
    }
}
