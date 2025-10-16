//
//  StoredVariablesManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

 ///A singleton class responsible for managing stored variables using UserDefaults.
 ///This class provides methods to save and retrieve various application-related settings and tokens.
 
public class StoredVariablesManager: NSObject {

    /// The shared instance of `StoredVariablesManager`.
    public static let shared = StoredVariablesManager()
    
    private let initStatus = "INIT_STATUS"
    private let critCoreDataKey = "CRIT_DB"
    
    private let tokenKey = "CURRENT_TOKEN"
    private let manualTokenKey = "MANUAL_TOKEN"
    private let currentTokenKey = "CURRENT_TOKEN"
    private let savedTokenKey = "SAVED_TOKEN"
    
    private let appGroupNameKey = "GROUP_NAME"
    
    //retry count keys
    private let pushSubLocalRetryKey = "PUSH_SUB_LOC_RETRY"
    private let tokenUpdateLocalRetryKey = "TOKEN_UPDATE_LOC_RETRY"
    private let pushEventLocalRetryKey = "PUSH_EVENT_LOC_RETRY"
    private let mobileEventLocalRetryKey = "MOB_EVENT_LOC_RETRY"
    private let profileSearchKey = "PROFILE_SEARCH"
   
    /// Sets true if there are critical errors in the database.
    ///
    /// - Parameter value: A boolean value indicating that critical errors have been detected in the database.
    public func setCritDB(value: Bool) {
        UserDefaults.standard.set(value, forKey: critCoreDataKey)
    }
    
    /// Checks for critical errors in the database.
    ///
    /// - Returns: `true` if there are critical database errors.
    func getDbErrorStatus() -> Bool {
        return UserDefaults.standard.bool(forKey: critCoreDataKey)
    }
    
    /// Stores the App Group name using the group-specific `UserDefaults`.
    ///
    /// - Parameter value: The App Group identifier to store.
    public func setGroupsName(value: String?) {
        UserDefaults.standard.set(value, forKey: appGroupNameKey)
    }

    /// Retrieves the App Group name from the standard UserDefaults.
    ///
    /// - Returns: The stored App Group identifier, or `nil` if not set.
    public func getGroupName() -> String? {
        let name = UserDefaults.standard.string(forKey: appGroupNameKey)
        if name == nil {
            errorEvent(#function, error: appGroupIsNotSet)
        }
        return name
    }
    
    /// Stores the manual token in UserDefaults if both `provider` and `token` are non-empty.
    ///
    /// - Parameters:
    ///   - provider: Non-optional provider string.
    ///   - token: Optional token string. If `nil`, nothing is saved.
    public func setPushToken(provider: String, token: String?) {
        guard let token = token,
              !provider.isEmpty,
              !token.isEmpty else {
            return
        }
        let stored = TokenData(provider: provider, token: token)
        if let data = try? JSONEncoder().encode(stored) {
            let defaults = UserDefaults(suiteName: getGroupName() ?? "")
            defaults?.set(data, forKey: manualTokenKey)
        }
    }
    
    /// Retrieves the manual stored token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    func getManualToken() -> TokenData? {
        let defaults = UserDefaults(suiteName: getGroupName() ?? "")
        guard let data = defaults?.data(forKey: manualTokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
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
            let defaults = UserDefaults(suiteName: getGroupName() ?? "")
            defaults?.set(data, forKey: tokenKey)
        }
    }
    
    /// Retrieves the saved token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    func getSavedToken() -> TokenData? {
        let defaults = UserDefaults(suiteName: getGroupName() ?? "")
        guard let data = defaults?.data(forKey: tokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
    
    /// Removes the manual stored token from UserDefaults.
    ///
    /// Use this when the current token is invalidated or replaced.
    func clearManualToken() {
        let defaults = UserDefaults(suiteName: getGroupName() ?? "")
        defaults?.removeObject(forKey: manualTokenKey)
    }
    
    /// Removes the saved (last known valid) token from UserDefaults.
    ///
    /// Typically used during logout or full reset of subscription state.
    func clearSavedToken() {
        let defaults = UserDefaults(suiteName: getGroupName() ?? "")
        defaults?.removeObject(forKey: tokenKey)
    }
    
    /// Updates the local retry count for push subscription requests.
    ///
    /// - Parameter value: The new retry count to be stored.
    func setSubRetryCount(value: Int) {
        UserDefaults.standard.set(value, forKey: pushSubLocalRetryKey)
    }
    
    /// Retrieves the local retry count for push subscription requests.
    ///
    /// - Returns: The current retry count. Defaults to `1` if no value is found.
    func getSubRetryCount() -> Int? {
        return UserDefaults.standard.object(forKey: pushSubLocalRetryKey) as? Int ?? 1
    }

    /// Updates the local retry count for token update requests.
    ///
    /// - Parameter value: The new retry count to be stored.
    func setUpdateRetryCount(value: Int) {
        UserDefaults.standard.set(value, forKey: tokenUpdateLocalRetryKey)
    }

    /// Retrieves the local retry count for token update requests.
    ///
    /// - Returns: The current retry count. Defaults to `1` if no value is found.
    func getUpdateRetryCount() -> Int? {
        return UserDefaults.standard.object(forKey: tokenUpdateLocalRetryKey) as? Int ?? 1
    }

    /// Updates the local retry count for push event request.
    ///
    /// - Parameter value: The new retry count to be stored.
    func setPushEventRetryCount(value: Int) {
        UserDefaults.standard.set(value, forKey: pushEventLocalRetryKey)
    }

    /// Retrieves the local retry count for push event request.
    ///
    /// - Returns: The current retry count or `nil` if no value is found.
    func getPushEventRetryCount() -> Int? {
        return UserDefaults.standard.object(forKey: pushEventLocalRetryKey) as? Int
    }
    
    /// Updates the local retry count for mobile event request.
    ///
    /// - Parameter value: The new retry count to be stored.
    func setMobileEventRetryCount(value: Int) {
        UserDefaults.standard.set(value, forKey: mobileEventLocalRetryKey)
    }

    /// Retrieves the local retry count for mobile event request.
    ///
    /// - Returns: The current retry count or `nil` if no value is found.
    func getMobileEventRetryCount() -> Int? {
        return UserDefaults.standard.object(forKey: mobileEventLocalRetryKey) as? Int
    }
}
