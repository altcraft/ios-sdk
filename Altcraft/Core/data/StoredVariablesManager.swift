//
//  StoredVariablesManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A singleton actor responsible for managing shared SDK stored variables.
///
/// Owns the core UserDefaults keys: SDK initialization status, critical
/// database error state, App Group name, and logging status.
///
/// Push token and in-app presentation values are owned by the respective
/// modules: ``PushStoredVariables`` and ``InAppStoredVariables``.
@_spi(_Altcraft) public actor StoredVariablesManager {
    /// The shared instance of `StoredVariablesManager`.
    public static let shared = StoredVariablesManager()

    private static let initStatusKey = "\(Constants.UDPrefix)_INIT_STATUS"
    private static let critCoreDataKey = "\(Constants.UDPrefix)_CRIT_DB"
    private static let appGroupNameKey = "\(Constants.UDPrefix)_GROUP_NAME"
    private static let loggingStatusKey = "\(Constants.UDPrefix)_LOGGING_STATUS"
    private static let currentRTokenKey = "\(Constants.UDPrefix)_RTOKEN"

    private init() {}

    /// Builds the CRIT_DB storage key for one module.
    ///
    /// The Core module keeps the legacy unsuffixed key so previously
    /// persisted state maps to Core; every other module owns an isolated
    /// suffixed key and its failure never affects other modules.
    ///
    /// - Parameter module: Module model name owning the flag (e.g. "Core", "Push").
    /// - Returns: The UserDefaults key storing the module's critical flag.
    private static func critDBKey(for module: String) -> String {
        module == Constants.CoreData.coreModelName
            ? critCoreDataKey
            : "\(critCoreDataKey)_\(module)"
    }

    /// Stores the App Group name using the standard `UserDefaults`.
    ///
    /// - Parameter value: The App Group identifier to store.
    public nonisolated func setGroupsName(value: String?) {
        UserDefaults.standard.set(value, forKey: Self.appGroupNameKey)
    }

    /// Retrieves the App Group name from the standard UserDefaults.
    ///
    /// - Returns: The stored App Group identifier, or `nil` if not set.
    public nonisolated func getGroupName() -> String? {
        let name = UserDefaults.standard.string(
            forKey: Self.appGroupNameKey
        )

        if name == nil {
            CoreLog.error(#function, error: CoreEvents.appGroupIsNotSet)
        }
        return name
    }

    /// Sets true if there are critical errors in the database.
    ///
    /// - Parameter value: A boolean value indicating that critical errors have been detected in the database.
    /// Stores the critical Core Data error flag of one module.
    ///
    /// Each SDK module owns an isolated flag: a failure of one module's
    /// persistent store never blocks another module's operations.
    ///
    /// - Parameters:
    ///   - value: `true` marks the module's Core Data stack as unrecoverably
    ///     broken; `false` restores it after a successful store load.
    ///   - module: Module model name owning the flag (e.g. "Core", "Push").
    @_spi(_Altcraft) public nonisolated func setCritDB(value: Bool, module: String) {
        UserDefaults.standard.set(
            value,
            forKey: Self.critDBKey(for: module)
        )
    }

    /// Returns the critical Core Data error flag of one module.
    ///
    /// - Parameter module: Module model name owning the flag (e.g. "Core", "Push").
    /// - Returns: `true` when the module's Core Data stack is in critical state.
    @_spi(_Altcraft) public nonisolated func getDbErrorStatus(module: String) -> Bool {
        UserDefaults.standard.bool(
            forKey: Self.critDBKey(for: module)
        )
    }

    /// Stores the critical Core Data error flag of the Core module.
    ///
    /// Core-scoped legacy entry point: equivalent to
    /// `setCritDB(value:module:)` with the Core module name. The Core
    /// module's flag additionally gates request building in
    /// `CoreRequestBuilder`, because every module depends on Core's
    /// configuration and authentication data.
    ///
    /// - Parameter value: `true` marks the Core Data stack as unrecoverably
    ///   broken; `false` restores it after a successful store load.
    @_spi(_Altcraft) public nonisolated func setCritDB(value: Bool) {
        setCritDB(value: value, module: Constants.CoreData.coreModelName)
    }

    /// Returns the critical Core Data error flag of the Core module.
    ///
    /// - Returns: `true` when the Core module's Core Data stack is in
    ///   critical state.
    @_spi(_Altcraft) public nonisolated func getDbErrorStatus() -> Bool {
        getDbErrorStatus(module: Constants.CoreData.coreModelName)
    }

    /// Stores the logging status flag in UserDefaults (App Group if available).
    ///
    /// - Parameter enabled: `true` to enable internal SDK logging, `false` to disable it.
    ///   Pass `nil` to clear the stored value.
    @_spi(_Altcraft) public nonisolated func setLoggingStatus(enabled: Bool?) {
        let defaults = UserDefaults(suiteName: getGroupName())
        defaults?.set(enabled, forKey: Self.loggingStatusKey)
    }

    /// Retrieves the logging status flag from UserDefaults (App Group if available).
    ///
    /// - Returns: `true` if logging is enabled, `false` if disabled,
    ///   or `nil` if no value is stored or App Group is unavailable.
    @_spi(_Altcraft) public nonisolated func getLoggingStatus() -> Bool? {
        guard let defaults = UserDefaults(suiteName: getGroupName()) else {
            return nil
        }
        guard defaults.object(forKey: Self.loggingStatusKey) != nil else { return nil }
        return defaults.bool(forKey: Self.loggingStatusKey)
    }

    /// Stores the current SDK role token used for change detection.
    ///
    /// Mirrors Android `Preferences.setCurrentRToken`.
    ///
    /// - Parameter value: The role token to store, or `nil` to remove it.
    @_spi(_Altcraft) public nonisolated func setCurrentRToken(value: String?) {
        UserDefaults.standard.set(value, forKey: Self.currentRTokenKey)
    }

    /// Returns the previously stored SDK role token.
    ///
    /// Mirrors Android `Preferences.getCurrentRToken`.
    ///
    /// - Returns: The stored role token, or `nil` if not set.
    @_spi(_Altcraft) public nonisolated func getCurrentRToken() -> String? {
        UserDefaults.standard.string(forKey: Self.currentRTokenKey)
    }

    /// Clears all **Core-owned** values stored in UserDefaults.
    ///
    /// Removes Core keys from standard and App Group UserDefaults.
    /// Module-owned keys (push tokens, in-app presentation state) are cleared
    /// by the respective modules through ``ModuleRegistry/notifyClear()``.
    ///
    /// Per-module critical Core Data flags (`_CRIT_DB_<module>`) are
    /// intentionally preserved: clearing data does not repair a broken
    /// store, and the flags self-heal only on a successful store load.
    ///
    /// This method removes only Core-owned SDK-prefixed keys and keeps
    /// unrelated app values.
    @_spi(_Altcraft) public func clearAllSDKUserDefaults() {
        let prefix = Constants.UDPrefix

        let groupName = UserDefaults.standard.string(
            forKey: Self.appGroupNameKey
        )

        let keys = [
            "\(prefix)_INIT_STATUS",
            Self.critCoreDataKey,
            Self.appGroupNameKey,
            Self.loggingStatusKey,
            Self.currentRTokenKey
        ]

        keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }

        if let groupName, let groupDefaults = UserDefaults(suiteName: groupName) {
            keys.forEach {
                groupDefaults.removeObject(forKey: $0)
            }
        }
    }
}
