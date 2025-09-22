//
//  JWTSettingManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

class JWTSettingManager: ObservableObject {
    @Published var anonJWT: String = ""
    @Published var regJWT: String = ""
    
    init() {
        loadJWTs()
    }
    
    func loadJWTs() {
        anonJWT = JWTManager.shared.getAnonJWT() ?? ""
        regJWT = JWTManager.shared.getRegJWT() ?? ""
    }
    
    func saveJWTs() {
        if !anonJWT.isEmpty {
            JWTManager.shared.setAnonJWT(anonJWT)
        }
        if !regJWT.isEmpty {
            JWTManager.shared.setRegJWT(regJWT)
        }
        JWTManager.shared.setJWT(anonJWT)
    }
    
    func clearJWTs() {
        anonJWT = ""
        regJWT = ""
        JWTManager.shared.clearJWT()
    }
}
