//
//  AppUserDefaults.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft

let configKey = "SDKConfig"
let subscriptionSettingKey = "SubscriptionSettings"
private let apnsTokenKey = "apnsTokenString"
private let apnsTokenDataKey = "apnsTokenData"

/// Stores APNs token (converted from Data to hex String)
func setAPNsTokenInUserDefault(_ deviceToken: Data) {
    UserDefaults.standard.set(deviceToken, forKey: apnsTokenDataKey)
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    UserDefaults.standard.set(tokenString, forKey: apnsTokenKey)
}

/// Retrieves APNs token as String
func getAPNsTokenFromUserDefault() -> String? {
    return UserDefaults.standard.string(forKey: apnsTokenKey)
}

/// Retrieves APNs token as Data (если не сохранён, вернёт nil)
func getAPNsTokenDataFromUserDefaults() -> Data? {
    return UserDefaults.standard.data(forKey: apnsTokenDataKey)
}

func setConfigInUserDefaults(config: AppConfig, completion: ((Bool) -> Void)? = nil) {
    if let encoded = try? JSONEncoder().encode(config) {
        UserDefaults.standard.set(encoded, forKey: configKey)
        completion?(true)
    } else {
        completion?(false)
    }
}

func getConfigFromUserDefault() -> AppConfig? {
    guard let data = UserDefaults.standard.data(forKey: configKey) else {
        return nil
    }
    return try? JSONDecoder().decode(AppConfig.self, from: data)
}

func setSubscriptionSettingToUserDefaults(_ settings: SubscribeSettings) {
    do {
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        UserDefaults.standard.set(data, forKey: subscriptionSettingKey)
    } catch {
        print("Failed to encode subscription settings: \(error.localizedDescription)")
    }
}

func getSubscriptionSettingFromUserDefaults() -> SubscribeSettings {
    guard let data = UserDefaults.standard.data(forKey: subscriptionSettingKey) else {
        return SubscribeSettings.getDefault()
    }
    
    do {
        let decoder = JSONDecoder()
        return try decoder.decode(SubscribeSettings.self, from: data)
    } catch {
        print("Failed to decode subscription settings: \(error.localizedDescription)")
        return SubscribeSettings.getDefault()
    }
}
