//
//  JWTManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

final class JWTManager {
    static let shared = JWTManager()
    
    private static let suiteName = appGroup
    
    private let anonKey = "ANON_JWT"
    private let regKey = "REG_JWT"
    private let authKey = "AUTH_KEY"
    private let JWTKey = "JWT_KEY"

    private let defaults: UserDefaults?

    private init() {
        self.defaults = UserDefaults(suiteName: Self.suiteName)
        
        let regJWT = regJWT ?? getRegJWT()
        let anonJWT = anonJWT ?? getAnonJWT()
      
        if getAuthFlag() == true, let rJWT = regJWT {
            setJWT(rJWT)
        }
       
        if getAuthFlag() == false, let aJWT = anonJWT {
            setJWT(aJWT)
        }
    }

    func setAnonJWT(_ token: String) {
        defaults?.set(token, forKey: anonKey)
    }

    func setRegJWT(_ token: String) {
        defaults?.set(token, forKey: regKey)
    }

    func getAnonJWT() -> String? {
        defaults?.string(forKey: anonKey)
    }

    func getRegJWT() -> String? {
        defaults?.string(forKey: regKey)
    }
    
    func setAuthStatus(_ value: Bool?) {
        defaults?.set(value, forKey: authKey)
    }

    func getAuthFlag() -> Bool? {
        defaults?.bool(forKey: authKey)
    }
    
    func setJWT(_ token: String?) {
        defaults?.set(token, forKey: JWTKey)
    }
    
    func getJWT() -> String? {
        defaults?.string(forKey: JWTKey)
    }
    
    func clearJWT() {
        defaults?.removeObject(forKey: anonKey)
        defaults?.removeObject(forKey: regKey)
        defaults?.removeObject(forKey: authKey)
        defaults?.removeObject(forKey: JWTKey)
    }
}
