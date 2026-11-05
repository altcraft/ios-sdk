//
//  AppUserDefaults.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget

let configKey = "SDKConfig"
let subscriptionSettingKey = "SubscriptionSettings"

private let apnsTokenKey = "apnsTokenString"
private let apnsTokenDataKey = "apnsTokenData"

private let pushSubscriptionStatusKey = "pushSubscriptionStatus"
private let inAppSubscriptionStatusKey = "inAppSubscriptionStatus"
private let internalAuthStatusKey = "internalAuthStatus"

// MARK: - APNs Token

/// Stores the APNs device token in UserDefaults.
///
/// - Parameter deviceToken: Raw APNs token data.
func setAPNsTokenInUserDefault(_ deviceToken: Data) {
    UserDefaults.standard.set(
        deviceToken,
        forKey: apnsTokenDataKey
    )
    
    let tokenString = deviceToken
        .map {
            String(format: "%02x", $0)
        }
        .joined()
    
    UserDefaults.standard.set(
        tokenString,
        forKey: apnsTokenKey
    )
}

/// Returns the stored APNs token string, or `nil` when absent.
func getAPNsTokenFromUserDefault() -> String? {
    UserDefaults.standard.string(
        forKey: apnsTokenKey
    )
}

/// Returns the stored APNs token data, or `nil` when absent.
func getAPNsTokenDataFromUserDefaults() -> Data? {
    UserDefaults.standard.data(
        forKey: apnsTokenDataKey
    )
}

// MARK: - SDK Configuration

/// Saves the app configuration (API URL, rToken, providers) to UserDefaults.
///
/// - Parameters:
///   - config: Configuration to store.
///   - completion: Called with `true` when the configuration is stored.
func setConfigInUserDefaults(
    config: AppConfig,
    completion: ((Bool) -> Void)? = nil
) {
    do {
        let encoded = try JSONEncoder().encode(config)
        
        UserDefaults.standard.set(
            encoded,
            forKey: configKey
        )
        
        completion?(true)
    } catch {
        print(
            "Failed to encode SDK configuration: \(error.localizedDescription)"
        )
        
        completion?(false)
    }
}

/// Loads the app configuration from UserDefaults, or `nil` when absent.
func getConfigFromUserDefault() -> AppConfig? {
    guard let data = UserDefaults.standard.data(
        forKey: configKey
    ) else {
        return nil
    }
    
    do {
        return try JSONDecoder().decode(
            AppConfig.self,
            from: data
        )
    } catch {
        print(
            "Failed to decode SDK configuration: \(error.localizedDescription)"
        )
        
        return nil
    }
}

// MARK: - Subscription Settings

/// Saves subscription settings to UserDefaults.
///
/// - Parameter settings: Settings to store.
func setSubscriptionSettingToUserDefaults(
    _ settings: SubscribeSettings
) {
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        UserDefaults.standard.set(
            data,
            forKey: subscriptionSettingKey
        )
    } catch {
        print(
            "Failed to encode subscription settings: \(error.localizedDescription)"
        )
    }
}

/// Loads subscription settings from UserDefaults; returns defaults
/// when nothing is stored.
func getSubscriptionSettingFromUserDefaults() -> SubscribeSettings {
    guard let data = UserDefaults.standard.data(
        forKey: subscriptionSettingKey
    ) else {
        return SubscribeSettings.getDefault()
    }
    
    do {
        let decoder = JSONDecoder()
        
        return try decoder.decode(
            SubscribeSettings.self,
            from: data
        )
    } catch {
        print(
            "Failed to decode subscription settings: \(error.localizedDescription)"
        )
        
        return SubscribeSettings.getDefault()
    }
}

// MARK: - Push Subscription PushStatusProcess

/// Stores the push subscription status string.
///
/// - Parameter status: Status to store.
func setPushSubscriptionStatusToUserDefaults(
    _ status: String
) {
    UserDefaults.standard.set(
        status,
        forKey: pushSubscriptionStatusKey
    )
}

/// Returns the stored push subscription status.
func getPushSubscriptionStatusFromUserDefaults() -> String {
    UserDefaults.standard.string(
        forKey: pushSubscriptionStatusKey
    ) ?? AppConstants.SubscriptionStatus.unsubscribed
}

/// Removes the stored push subscription status.
func clearPushSubscriptionStatusFromUserDefaults() {
    UserDefaults.standard.removeObject(
        forKey: pushSubscriptionStatusKey
    )
}

// MARK: - In-App Subscription PushStatusProcess

/// Stores the in-app subscription status string.
///
/// - Parameter status: Status to store.
func setInAppSubscriptionStatusToUserDefaults(
    _ status: String
) {
    UserDefaults.standard.set(
        status,
        forKey: inAppSubscriptionStatusKey
    )
}

/// Returns the stored in-app subscription status.
func getInAppSubscriptionStatusFromUserDefaults() -> String {
    UserDefaults.standard.string(
        forKey: inAppSubscriptionStatusKey
    ) ?? AppConstants.SubscriptionStatus.unsubscribed
}

/// Removes the stored in-app subscription status.
func clearInAppSubscriptionStatusFromUserDefaults() {
    UserDefaults.standard.removeObject(
        forKey: inAppSubscriptionStatusKey
    )
}

// MARK: - Internal Auth PushStatusProcess

/// Stores the internal authentication status flag.
///
/// - Parameter status: `true` when the user is authenticated.
func setInternalAuthStatusToUserDefaults(
    _ status: Bool
) {
    UserDefaults.standard.set(
        status,
        forKey: internalAuthStatusKey
    )
}

/// Returns the stored internal authentication status.
func getInternalAuthStatusFromUserDefaults() -> Bool {
    UserDefaults.standard.bool(
        forKey: internalAuthStatusKey
    )
}

/// Removes the stored internal authentication status.
func clearInternalAuthStatusFromUserDefaults() {
    UserDefaults.standard.removeObject(
        forKey: internalAuthStatusKey
    )
}

// MARK: - SDK Indicator Statuses

/// Clears all SDK indicator statuses from UserDefaults.
func clearSdkIndicatorStatusesFromUserDefaults() {
    setPushSubscriptionStatusToUserDefaults(
        AppConstants.SubscriptionStatus.unsubscribed
    )
    
    setInAppSubscriptionStatusToUserDefaults(
        AppConstants.SubscriptionStatus.unsubscribed
    )
    
    setInternalAuthStatusToUserDefaults(false)
}

// MARK: - SDK Initialization

/// Initializes Altcraft SDK with the provided application configuration.
///
/// - Parameters:
///   - config: Application configuration containing API URL,
///     resource token and push provider priority list.
///   - completion: Called after SDK initialization is completed.
func initSDK(
    config: AppConfig?,
    completion: (@Sendable () -> Void)? = nil
) {
    guard let config else {
        return
    }
    
    let rToken: String? = {
        guard let token = config.rToken,
              !token.isEmpty else {
            return nil
        }
        
        return token
    }()
    
    let configuration = AltcraftConfiguration.Builder(
        apiUrl: config.apiUrl,
        rToken: rToken
    )
    .pushConfig(
        providerPriority: config.providerNames
    )
    .build()
    
    AltcraftSDK.initialization(
        configuration: configuration
    ) { success in
        guard success else {
            return
        }
        
        completion?()
    }
}
