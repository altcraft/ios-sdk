//
//  SubscribeSettingManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftTarget
import SwiftUI

/// Manages subscription settings entered through the UI.
class SubscribeSettingManager: ObservableObject {
    // MARK: - Published Properties
    @Published var subscribeSettings = SubscribeSettings.getDefault()
    @Published var newFieldKey = ""
    @Published var newFieldValue = ""

    init() {
        subscribeSettings = getSubscriptionSettingFromUserDefaults()
    }
    
    // MARK: - Settings Properties
    var sync: Bool {
        get { subscribeSettings.sync }
        set {
            subscribeSettings.sync = newValue
            objectWillChange.send()
        }
    }
    
    var replace: Bool {
        get { subscribeSettings.replace }
        set {
            subscribeSettings.replace = newValue
            objectWillChange.send()
        }
    }
    
    var skipTriggers: Bool {
        get { subscribeSettings.skipTriggers }
        set {
            subscribeSettings.skipTriggers = newValue
            objectWillChange.send()
        }
    }
    
    // MARK: - Public Methods
    /// Persists the current subscription settings to UserDefaults.
    func saveSettings() {
        setSubscriptionSettingToUserDefaults(subscribeSettings)
    }
    
    /// Resets subscription settings to their defaults.
    func clearSettings() {
        subscribeSettings = SubscribeSettings.getDefault()
        newFieldKey = ""
        newFieldValue = ""
        UserDefaults.standard.removeObject(forKey: subscriptionSettingKey)
    }
    
    /// Adds a custom field to the settings.
    ///
    /// - Parameters:
    ///   - key: Field key.
    ///   - value: Field value.
    func addCustomField(key: String, value: String) {
        subscribeSettings.customFields[key] = value
        saveSettings()
    }
    
    /// Removes a custom field from the settings.
    ///
    /// - Parameter key: Field key.
    func removeCustomField(key: String) {
        subscribeSettings.customFields.removeValue(forKey: key)
        saveSettings()
    }
    
    /// Adds a profile field to the settings.
    ///
    /// - Parameters:
    ///   - key: Field key.
    ///   - value: Field value.
    func addProfileField(key: String, value: String) {
        subscribeSettings.profileFields[key] = value
        saveSettings()
    }
    
    /// Removes a profile field from the settings.
    ///
    /// - Parameter key: Field key.
    func removeProfileField(key: String) {
        subscribeSettings.profileFields.removeValue(forKey: key)
        saveSettings()
    }
    
    /// Adds a category to the settings.
    ///
    /// - Parameters:
    ///   - name: Category name.
    ///   - active: Whether the category is active.
    func addCat(name: String, active: Bool) {
        let newCat = CategoryData(name: name, title: name, steady: false, active: active)
        subscribeSettings.cats.append(newCat)
        saveSettings()
    }
    
    /// Removes a category from the settings.
    ///
    /// - Parameter name: Category name.
    func removeCat(name: String) {
        subscribeSettings.cats.removeAll { $0.name == name }
        saveSettings()
    }
}

/// Subscription settings model.
struct SubscribeSettings: Codable {
    var sync: Bool = true
    var replace: Bool = false
    var skipTriggers: Bool = false
    var customFields: [String: String] = [:]
    var profileFields: [String: String] = [:]
    var cats: [CategoryData] = []
    
    /// Returns the default subscription settings.
    static func getDefault() -> SubscribeSettings {
        return SubscribeSettings()
    }
    
    var customFieldsString: String {
        return "{\(customFields.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ", "))}"
    }
    
    var profileFieldsString: String {
        return "{\(profileFields.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
    }
    
    var catsString: String {
        return "[\(cats.map { "{\"name\": \"\($0.name ?? "")\", \"active\": \($0.active ?? false)}" }.joined(separator: ", "))]"
    }
    
    var catsDictionary: [String: String] {
        var dict = [String: String]()
        for cat in cats {
            if let name = cat.name {
                dict[name] = cat.active?.description ?? "false"
            }
        }
        return dict
    }
}
