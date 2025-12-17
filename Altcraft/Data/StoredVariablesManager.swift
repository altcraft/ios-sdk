//
//  StoredVariablesManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

/// A singleton class responsible for managing stored variables using UserDefaults.
/// This class provides methods to save and retrieve various application-related settings and tokens.
public class StoredVariablesManager: NSObject {
    
    /// The shared instance of `StoredVariablesManager`.
    public static let shared = StoredVariablesManager()
    
    private let initStatus = "\(Constants.UDPrefix)_INIT_STATUS"
    private let critCoreDataKey = "\(Constants.UDPrefix)_CRIT_DB"
    private let tokenKey = "\(Constants.UDPrefix)_CURRENT_TOKEN"
    private let manualTokenKey = "\(Constants.UDPrefix)_MANUAL_TOKEN"
    private let currentTokenKey = "\(Constants.UDPrefix)_CURRENT_TOKEN"
    private let savedTokenKey = "\(Constants.UDPrefix)_SAVED_TOKEN"
    private let appGroupNameKey = "\(Constants.UDPrefix)_GROUP_NAME"
    private let loggingStatusKey = "\(Constants.UDPrefix)_LOGGING_STATUS"
   
    /// Stores the App Group name using the standard `UserDefaults`.
    ///
    /// - Parameter value: The App Group identifier to store.
    public func setGroupsName(value: String?) {
        UserDefaults.standard.set(value, forKey: appGroupNameKey)
    }
    
    private let lock = NSLock()
    private var didLogMissingGroup = false

    /// Retrieves the App Group name from the standard UserDefaults.
    ///
    /// - Returns: The stored App Group identifier, or `nil` if not set.
    func getGroupName() -> String? {
        let name = UserDefaults.standard.string(forKey: appGroupNameKey)
        if name == nil {
            lock.lock()
            let shouldLog = !didLogMissingGroup
            if shouldLog {
                didLogMissingGroup = true
            }
            lock.unlock()

            if shouldLog {
                errorEvent(#function, error: appGroupIsNotSet)
            }
        }
        return name
    }
    
    /// Sets true if there are critical errors in the database.
    ///
    /// - Parameter value: A boolean value indicating that critical errors have been detected in the database.
    func setCritDB(value: Bool) {
        UserDefaults.standard.set(value, forKey: critCoreDataKey)
    }
    
    /// Checks for critical errors in the database.
    ///
    /// - Returns: `true` if there are critical database errors.
    func getDbErrorStatus() -> Bool {
        return UserDefaults.standard.bool(forKey: critCoreDataKey)
    }
    
    /// Stores the logging status flag in UserDefaults (App Group if available).
    ///
    /// - Parameter enabled: `true` to enable internal SDK logging, `false` to disable it.
    ///   Pass `nil` to clear the stored value.
    func setLoggingStatus(enabled: Bool?) {
        let defaults = UserDefaults(suiteName: getGroupName())
        defaults?.set(enabled, forKey: loggingStatusKey)
    }

    /// Retrieves the logging status flag from UserDefaults (App Group if available).
    ///
    /// - Returns: `true` if logging is enabled, `false` if disabled,
    ///   or `nil` if no value is stored or App Group is unavailable.
    func getLoggingStatus() -> Bool? {
        guard let defaults = UserDefaults(suiteName: getGroupName()) else {
            return nil
        }
        guard defaults.object(forKey: loggingStatusKey) != nil else {
            return nil
        }
        return defaults.bool(forKey: loggingStatusKey)
    }

    /// Retrieves the manual stored token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    func getManualToken() -> TokenData? {
        guard let data = UserDefaults.standard.data(forKey: manualTokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
    
    /// Stores the manual token in UserDefaults if both `provider` and `token` are non-empty.
    ///
    /// - Parameters:
    ///   - provider: Non-optional provider string.
    ///   - token: Optional token string. If `nil` or empty (or provider is empty),
    ///   the stored manual token is cleared.
    public func setPushToken(provider: String, token: String?) {
        guard let token = token,
              !provider.isEmpty,
              !token.isEmpty else {
            UserDefaults.standard.set(nil, forKey: manualTokenKey)
            return
        }
        let stored = TokenData(provider: provider, token: token)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: manualTokenKey)
        }
    }
    
    /// Stores the current token in UserDefaults if both `provider` and `token` are non-empty.
    ///
    /// - Parameters:
    ///   - provider: Non-optional provider string.
    ///   - token: Optional token string. If `nil`, nothing is saved.
    func setCurrentToken(provider: String?, token: String?) {
        guard let provider = provider,
              let token = token,
              !provider.isEmpty,
              !token.isEmpty else {
            return
        }

        let stored = TokenData(provider: provider, token: token)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: tokenKey)
        }
    }
    
    /// Retrieves the saved token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    func getSavedToken() -> TokenData? {
        guard let data = UserDefaults.standard.data(forKey: tokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
    
    /// Removes the manual stored token from UserDefaults.
    ///
    /// Use this when the current token is invalidated or replaced.
    func clearManualToken() {
        UserDefaults.standard.removeObject(forKey: manualTokenKey)
    }
    
    /// Removes the saved (last known valid) token from UserDefaults.
    ///
    /// Typically used during logout or full reset of subscription state.
    func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}

