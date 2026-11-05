//
//  PushConfigManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Storage abstraction for the push module configuration.
///
/// Decouples ``PushConfigManager`` from Core Data persistence so unit tests
/// can script read/write ordering.
protocol PushConfigStoring: Sendable {

    /// Reads the stored configuration.
    func get() async -> PushConfiguration

    /// Persists the configuration.
    func set(_ config: PushConfiguration) async

    /// Removes the stored configuration.
    func delete() async
}

/// Manages and caches the push module configuration.
///
/// Provides cached access to ``PushConfiguration`` while persistence
/// is handled by ``PushConfigDao``.
///
/// The actor isolation serializes `setConfig`/`getConfig`, so a cache
/// reset never races with a concurrent cache load. Persistence is applied
/// before the cache is invalidated (Android `TokenManager.changePriority`
/// parity): a concurrent read that loaded the previous value while the
/// write was in flight is wiped by the subsequent reset, so a stale
/// provider priority is never left in the cache.
actor PushConfigManager {

    /// Shared instance.
    static let shared = PushConfigManager()

    /// Thread-safe async cache for the push configuration.
    private let configLazy = AsyncLazy<PushConfiguration>()

    /// Storage used for persistence.
    private let storage: any PushConfigStoring

    private init() {
        self.storage = PushConfigDao()
    }

    /// Creates a manager over a custom storage (unit tests).
    ///
    /// - Parameter storage: Storage implementation to use.
    init(storage: any PushConfigStoring) {
        self.storage = storage
    }

    /// Returns the stored push module configuration.
    ///
    /// Returns a configuration with an empty provider priority when no stored
    /// configuration is available.
    func getConfig() async -> PushConfiguration {
        (try? await configLazy.get {
            await self.storage.get()
        }) ?? PushConfiguration(
            providerPriority: []
        )
    }

    /// Validates the push module configuration.
    ///
    /// A configuration whose provider priority contains an unsupported
    /// provider identifier is removed from persistence and the push module
    /// emits the corresponding module error event.
    ///
    /// - Parameter config: Push module configuration to validate.
    /// - Returns: `true` when the configuration is valid, otherwise `false`.
    func validateConfig(_ config: PushConfiguration) async -> Bool {
        let isValid = config.isProviderPriorityValid()
        if !isValid {
            await clearCache()
            PushLog.error(#function, error: PushModuleEvents.invalidPushProviders)
        }
        return isValid
    }

    /// Saves the push module configuration, invalidating the cache after
    /// persistence succeeds.
    ///
    /// - Parameter config: Push module configuration to save.
    func setConfig(_ config: PushConfiguration) async {
        await storage.set(config)
        await configLazy.reset()
    }

    /// Clears the stored push module configuration, invalidating the cache
    /// after the removal succeeds.
    func clearCache() async {
        await storage.delete()
        await configLazy.reset()
    }
}

extension PushConfigDao: PushConfigStoring {}
