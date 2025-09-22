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
    
    private static let suiteName = "group.altcraft.apns.example"

    private let anonKey = "ANON_JWT"
    private let regKey = "REG_JWT"
    private let authKey = "JWT_KEY"

    private let defaults: UserDefaults?

    private init() {
        self.defaults = UserDefaults(suiteName: Self.suiteName)
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

    func clearJWT() {
        defaults?.removeObject(forKey: anonKey)
        defaults?.removeObject(forKey: regKey)
        defaults?.removeObject(forKey: authKey)
    }

    func setJWT(_ value: String?) {
        defaults?.set(value, forKey: authKey)
    }

    func getJWT() -> String? {
        defaults?.string(forKey: authKey)
    }
}
