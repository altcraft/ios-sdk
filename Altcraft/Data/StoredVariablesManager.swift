//
//  StoredVariablesManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton actor responsible for managing stored variables using UserDefaults.
/// This actor provides methods to save and retrieve various application-related settings and tokens.
public actor StoredVariablesManager {
    
    /// The shared instance of `StoredVariablesManager`.
    public static let shared = StoredVariablesManager()
    
    private static let initStatusKey = "\(Constants.UDPrefix)_INIT_STATUS"
    private static let critCoreDataKey = "\(Constants.UDPrefix)_CRIT_DB"
    private static let tokenKey = "\(Constants.UDPrefix)_CURRENT_TOKEN"
    private static let manualTokenKey = "\(Constants.UDPrefix)_MANUAL_TOKEN"
    private static let currentTokenKey = "\(Constants.UDPrefix)_CURRENT_TOKEN"
    private static let savedTokenKey = "\(Constants.UDPrefix)_SAVED_TOKEN"
    private static let appGroupNameKey = "\(Constants.UDPrefix)_GROUP_NAME"
    private static let loggingStatusKey = "\(Constants.UDPrefix)_LOGGING_STATUS"
    
    private init() {}
    
    /// Stores the App Group name using the standard `UserDefaults`.
    ///
    /// - Parameter value: The App Group identifier to store.
    public nonisolated func setGroupsName(value: String?) {
        UserDefaults.standard.set(value, forKey: Self.appGroupNameKey)
    }
    
    /// Retrieves the App Group name from the standard UserDefaults.
    ///
    /// - Returns: The stored App Group identifier, or `nil` if not set.
    nonisolated func getGroupName() -> String? {
        let name = UserDefaults.standard.string(
            forKey: Self.appGroupNameKey
        )
        
        if name == nil {
            errorEvent(#function, error: appGroupIsNotSet)
        }
        return name
    }
    
    /// Sets true if there are critical errors in the database.
    ///
    /// - Parameter value: A boolean value indicating that critical errors have been detected in the database.
    nonisolated func setCritDB(value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.critCoreDataKey)
    }
    
    /// Checks for critical errors in the database.
    ///
    /// - Returns: `true` if there are critical database errors.
    nonisolated func getDbErrorStatus() -> Bool {
        UserDefaults.standard.bool(forKey: Self.critCoreDataKey)
    }
    
    /// Stores the logging status flag in UserDefaults (App Group if available).
    ///
    /// - Parameter enabled: `true` to enable internal SDK logging, `false` to disable it.
    ///   Pass `nil` to clear the stored value.
    nonisolated func setLoggingStatus(enabled: Bool?) {
        let defaults = UserDefaults(suiteName: getGroupName())
        defaults?.set(enabled, forKey: Self.loggingStatusKey)
    }
    
    /// Retrieves the logging status flag from UserDefaults (App Group if available).
    ///
    /// - Returns: `true` if logging is enabled, `false` if disabled,
    ///   or `nil` if no value is stored or App Group is unavailable.
    nonisolated func getLoggingStatus() -> Bool? {
        guard let defaults = UserDefaults(suiteName: getGroupName()) else {
            return nil
        }
        guard defaults.object(forKey: Self.loggingStatusKey) != nil else { return nil }
        return defaults.bool(forKey: Self.loggingStatusKey)
    }
    
    /// Stores the current token in UserDefaults if both `provider` and `token` are non-empty.
    ///
    /// - Parameters:
    ///   - provider: Non-optional provider string.
    ///   - token: Optional token string. If `nil`, nothing is saved.
    nonisolated func setCurrentToken(provider: String?, token: String?) {
        guard
            let provider,
            let token,
            !provider.isEmpty,
            !token.isEmpty
        else { return }
        
        let stored = TokenData(provider: provider, token: token)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.tokenKey)
        }
    }
    
    /// Retrieves the saved token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    nonisolated func getSavedToken() -> TokenData? {
        guard let data = UserDefaults.standard.data(forKey: Self.tokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
    
    
    /// Removes the saved (last known valid) token from UserDefaults.
    ///
    /// Typically used during logout or full reset of subscription state.
    nonisolated func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
    }
    
    private var manualTokenWaiters: [
        UUID: CheckedContinuation<TokenData?, Never>
    ] = [:]

    /// Removes the manual stored token from UserDefaults.
    ///
    /// Use this when the current token is invalidated or replaced.
    func clearManualToken() {
        UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

        if !manualTokenWaiters.isEmpty {
            let waiters = manualTokenWaiters.values
            manualTokenWaiters.removeAll()
            for waiter in waiters {
                waiter.resume(returning: nil)
            }
        }
    }

    /// Stores manual token or clears it.
    ///
    /// - Parameters:
    ///   - provider: Provider id (`ios-apns` / `ios-firebase` / `ios-huawei`).
    ///   - token: Token value.
    public func setPushToken(provider: String, token: String?) {
        guard let token, !provider.isEmpty, !token.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
            return
        }

        let stored = TokenData(provider: provider, token: token)
        
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: stored)
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
        }
    }

    /// Returns the manual push token.
    ///
    /// If a token is already stored, returns immediately.
    /// Otherwise, waits until a token is set via `setPushToken(provider:token:)`,
    /// but no longer than 5 seconds.
    ///
    /// - Returns: Stored `TokenData` once available, or `nil` on timeout.
    func getManualToken() async -> TokenData? {
        if let data = UserDefaults.standard.data(forKey: Self.manualTokenKey),
           let existing = try? JSONDecoder().decode(TokenData.self, from: data) {
            return existing
        }
        
        let id = UUID()

        return await withCheckedContinuation { continuation in
            manualTokenWaiters[id] = continuation

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }
                await self.resumeManualTokenWaiterIfNeeded(id: id)
            }
        }
    }

    private func resumeManualTokenWaiterIfNeeded(id: UUID) {
        guard let waiter = manualTokenWaiters.removeValue(forKey: id) else { return }
        waiter.resume(returning: nil)
    }
}
