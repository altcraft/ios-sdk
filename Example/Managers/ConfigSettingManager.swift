//
//  ConfigSettingManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Combine
import Altcraft

enum Provider: String, CaseIterable, Identifiable, Codable, Hashable {
    case fcm = "FCM"
    case hms = "HMS"
    case apns = "APNs"
    
    var id: String { rawValue }
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .apns: return "ic_apns_logo"
        case .fcm: return "ic_fcm_logo"
        case .hms: return "ic_hms_logo"
        }
    }
    
    // Добавляем преобразование в server-формат
    var serverName: String {
        switch self {
        case .fcm: return Constants.ProviderName.firebase
        case .hms: return Constants.ProviderName.huawei
        case .apns: return Constants.ProviderName.apns
        }
    }
}

// MARK: - Config Data Model
struct AppConfig: Codable {
    var apiUrl: String
    var rToken: String?
    var providerNames: [String]  
    
    init(apiUrl: String = "", rToken: String? = nil, providerNames: [String] = []) {
        self.apiUrl = apiUrl
        self.rToken = rToken
        self.providerNames = providerNames
    }
}

// MARK: - Config Manager
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
                case Constants.ProviderName.firebase: return .fcm
                case Constants.ProviderName.apns: return .apns
                case Constants.ProviderName.huawei: return .hms
                default: return nil
                }
            }
        }
    }
    
    func saveConfig(completion: ((Bool) -> Void)? = nil) {
        let providerNames = providers.map { $0.serverName }
        
        let config = AppConfig(
            apiUrl: apiUrl,
            rToken: rToken.isEmpty ? nil : rToken,
            providerNames: providerNames
        )
        setConfigInUserDefaults(config: config, completion: completion)
    }

    func resetConfig() {
        apiUrl = ""
        rToken = ""
        providers = []
        UserDefaults.standard.removeObject(forKey: configKey)
    }
    
    func addProvider(_ provider: Provider) {
        if !providers.contains(provider) {
            providers.append(provider)
            saveConfig()
        }
    }
    
    func removeProvider(_ provider: Provider) {
        providers.removeAll { $0 == provider }
        saveConfig()
    }
}

