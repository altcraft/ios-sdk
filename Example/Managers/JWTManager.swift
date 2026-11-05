//
//  JWTManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush

/// Manages JWT values and the authentication mode.
final class JWTManager: @unchecked Sendable {

    static let shared = JWTManager()

    private static let suiteName = appGroupID

    private let anonKey = "ANON_JWT"
    private let regKey = "REG_JWT"
    private let authKey = "AUTH_KEY"
    private let JWTKey = "JWT_KEY"

    private let defaults: UserDefaults?

    private init() {
        defaults = UserDefaults(suiteName: Self.suiteName)
        updateJWT()
    }

    // MARK: - Anonymous JWT

    /// Stores the anonymous user JWT.
    ///
    /// - Parameter token: JWT value.
    func setAnonJWT(_ token: String) {
        defaults?.set(token, forKey: anonKey)
        updateJWT()
    }

    /// Returns the anonymous user JWT, or `nil` when absent.
    func getAnonJWT() -> String? {
        if let stored = defaults?.string(forKey: anonKey),
           !stored.isEmpty {
            return stored
        }

        return anonJWT
    }

    // MARK: - Registered JWT

    /// Stores the registered user JWT.
    ///
    /// - Parameter token: JWT value.
    func setRegJWT(_ token: String) {
        defaults?.set(token, forKey: regKey)
        updateJWT()
    }

    /// Returns the registered user JWT, or `nil` when absent.
    func getRegJWT() -> String? {
        if let stored = defaults?.string(forKey: regKey),
           !stored.isEmpty {
            return stored
        }

        return regJWT
    }

    // MARK: - Auth PushStatusProcess

    /// Stores the authenticated user flag.
    ///
    /// - Parameter value: `true` for a registered user, `false` for
    ///   anonymous, `nil` to clear.
    func setAuthStatus(_ value: Bool?) {
        if let value {
            defaults?.set(value, forKey: authKey)
        } else {
            defaults?.removeObject(forKey: authKey)
        }

        updateJWT()
    }

    /// Returns the authenticated user flag, or `nil` when unset.
    func getAuthFlag() -> Bool? {
        guard defaults?.object(forKey: authKey) != nil else {
            return nil
        }

        return defaults?.bool(forKey: authKey)
    }

    // MARK: - Current JWT

    /// Stores the JWT for the current authentication mode.
    ///
    /// - Parameter token: JWT value, or `nil` to clear.
    func setJWT(_ token: String?) {
        if let token, !token.isEmpty {
            defaults?.set(token, forKey: JWTKey)
        } else {
            defaults?.removeObject(forKey: JWTKey)
        }
    }

    /// Returns the JWT for the current authentication mode, or `nil`.
    func getJWT() -> String? {

        if let jwt = defaults?.string(forKey: JWTKey),
           !jwt.isEmpty {
            return jwt
        }

        switch getAuthFlag() {

        case true:
            return getRegJWT()

        case false:
            return getAnonJWT()

        case nil:
            return getAnonJWT()
        }
    }

    // MARK: - Update

    /// Synchronizes the stored JWT when the authentication mode changes.
    private func updateJWT() {
        setJWT(getAuthFlag() == true ? getRegJWT() : getAnonJWT())
    }

    // MARK: - Clear

    /// Removes the stored JWT values.
    func clearJWT() {
        defaults?.removeObject(forKey: anonKey)
        defaults?.removeObject(forKey: regKey)
        defaults?.removeObject(forKey: authKey)
        defaults?.removeObject(forKey: JWTKey)
    }
}
