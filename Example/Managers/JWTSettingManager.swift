//
//  JWTSettingManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush

/// Holds JWT values edited in the UI.
class JWTSettingManager: ObservableObject {
    @Published var anonJWT: String = ""
    @Published var regJWT: String = ""
    
    init() {
        loadJWTs()
    }
    
    /// Loads JWT values from UserDefaults into the UI.
    func loadJWTs() {
        anonJWT = JWTManager.shared.getAnonJWT() ?? ""
        regJWT = JWTManager.shared.getRegJWT() ?? ""
    }
    
    /// Saves the current JWT values to UserDefaults.
    func saveJWTs() {
        if !anonJWT.isEmpty {
            JWTManager.shared.setAnonJWT(anonJWT)
        }
        if !regJWT.isEmpty {
            JWTManager.shared.setRegJWT(regJWT)
        }
    }
    
    /// Clears the stored JWT values.
    func clearJWTs() {
        anonJWT = ""
        regJWT = ""
        JWTManager.shared.clearJWT()
    }
}
