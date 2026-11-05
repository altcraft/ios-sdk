//
//  ConfigSettingManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import SwiftUI
import AltcraftCore
import AltcraftPush
import AltcraftTarget
import Combine
import AltcraftPush

/// Push provider selectable in the configuration UI.
enum Provider: String, CaseIterable, Identifiable, Codable, Hashable {
    case fcm = "FCM"
    case hms = "HMS"
    case apns = "APNs"
    
    var id: String {
        rawValue
    }
    
    var displayName: String {
        rawValue
    }
    
    var iconName: String {
        switch self {
        case .apns:
            return "ic_apns_logo"
            
        case .fcm:
            return "ic_fcm_logo"
            
        case .hms:
            return "ic_hms_logo"
        }
    }
    
    var serverName: String {
        switch self {
        case .fcm:
            return PushConstants.ProviderName.firebase
            
        case .hms:
            return PushConstants.ProviderName.huawei
            
        case .apns:
            return PushConstants.ProviderName.apns
        }
    }
}

// MARK: - Config Data Model

/// SDK configuration entered through the UI.
struct AppConfig: Codable {
    var apiUrl: String
    var rToken: String?
    var providerNames: [String]
    
    init(
        apiUrl: String = "",
        rToken: String? = nil,
        providerNames: [String] = []
    ) {
        self.apiUrl = apiUrl
        self.rToken = rToken
        self.providerNames = providerNames
    }
}

// MARK: - Config Manager

/// Manages the SDK configuration entered through the UI.
class ConfigSettingManager: ObservableObject {
    @Published var apiUrl: String = ""
    @Published var rToken: String = ""
    @Published var providers: [Provider] = []
    
    init() {
        let config = getConfigFromUserDefault()
        
        apiUrl = config?.apiUrl ?? ""
        rToken = config?.rToken ?? ""
        
        if let names = config?.providerNames {
            providers = names.compactMap { name in
                switch name {
                case PushConstants.ProviderName.firebase:
                    return .fcm
                    
                case PushConstants.ProviderName.apns:
                    return .apns
                    
                case PushConstants.ProviderName.huawei:
                    return .hms
                    
                default:
                    return nil
                }
            }
        }
    }
    
    /// Builds an `AppConfig` from the current UI fields and stores it.
    ///
    /// - Parameter completion: Called with the saved config, or `nil`
    ///   on failure.
    func saveConfig(
        completion: ((AppConfig?) -> Void)? = nil
    ) {
        let config = AppConfig(
            apiUrl: apiUrl,
            rToken: rToken.isEmpty ? nil : rToken,
            providerNames: providers.map { $0.serverName }
        )
        
        setConfigInUserDefaults(config: config) { success in
            completion?(success ? config : nil)
        }
    }
    
    /// Clears the stored configuration and resets the UI fields.
    func resetConfig() {
        apiUrl = ""
        rToken = ""
        providers = []
        
        UserDefaults.standard.removeObject(
            forKey: configKey
        )
    }
    
    /// Adds a push provider to the current selection.
    ///
    /// - Parameter provider: Provider to add.
    func addProvider(_ provider: Provider) {
        guard !providers.contains(provider) else {
            return
        }
        
        providers.append(provider)
    }
    
    /// Removes a push provider from the current selection.
    ///
    /// - Parameter provider: Provider to remove.
    func removeProvider(_ provider: Provider) {
        providers.removeAll {
            $0 == provider
        }
    }
}
