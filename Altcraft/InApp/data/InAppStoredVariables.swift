//
//  InAppStoredVariables.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// A singleton actor responsible for in-app related stored variables.
///
/// Persists in-app presentation timestamps in `UserDefaults` with an
/// SDK-prefixed key. The in-app module owns this key; core does not touch it.
actor InAppStoredVariables {

    /// The shared instance of `InAppStoredVariables`.
    static let shared = InAppStoredVariables()

    private static let lastInAppOpenTimeKey = "\(InAppConstants.UDPrefix)_LAST_OPEN_TIME"

    private init() {}

    /// Saves current in-app open time in milliseconds.
    ///
    /// Uses current system time, similarly to Android `setInAppLastOpenTime`.
    func setInAppLastOpenTime() {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        UserDefaults.standard.set(now, forKey: Self.lastInAppOpenTimeKey)
    }

    /// Returns the last saved in-app open time in milliseconds.
    ///
    /// - Returns: Saved timestamp in milliseconds, or `0` if no value exists.
    nonisolated func getInAppLastOpenTime() -> Int64 {
        let value = UserDefaults.standard.object(forKey: Self.lastInAppOpenTimeKey) as? NSNumber
        return value?.int64Value ?? 0
    }

    /// Clears the in-app stored values from UserDefaults.
    ///
    /// Removes the in-app keys from standard and App Group UserDefaults.
    func clear() {
        UserDefaults.standard.removeObject(forKey: Self.lastInAppOpenTimeKey)

        if let groupName = StoredVariablesManager.shared.getGroupName(),
           let groupDefaults = UserDefaults(suiteName: groupName) {
            groupDefaults.removeObject(forKey: Self.lastInAppOpenTimeKey)
        }
    }
}
