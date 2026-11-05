//
//  JWTManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Singleton manager for handling JWT authentication.
class JWTManager: @unchecked Sendable {

    /// Shared instance of JWTManager.
    static let shared = JWTManager()

    /// State queue to protect access to `jwtProvider`.
    private let stateQueue = DispatchQueue(
        label: "com.altcraft.jwtmanager.state"
    )
    private var _jwtProvider: JWTInterface?

    private init() {}

    /// Registers a JWT provider globally for the SDK.
    ///
    /// - Parameter provider: An implementation of `JWTInterface` that supplies JWT tokens.
    func register(_ provider: JWTInterface) {
        stateQueue.sync {
            self._jwtProvider = provider
        }
    }

    /// Retrieves the current JWT token from the registered provider.
    ///
    /// - Returns: A JWT token as a string, or `nil` if no provider is set.
    func getJWT() -> String? {
        let provider = stateQueue.sync { self._jwtProvider }
        return provider?.getToken()
    }
}

/// Extracts the role token (`rtoken` claim) from a JWT payload.
///
/// Mirrors Android `JWTProcessor.extractRToken`. A missing JWT is a normal
/// state (the provider is not registered yet) and is treated as "no role
/// token" without emitting an error.
///
/// - Parameter jwt: The JWT token string (`header.payload.signature`), may be `nil`.
/// - Returns: The role token, or `nil` if the token is absent or the payload
///   cannot be decoded.
func extractRToken(jwt: String?) -> String? {
    guard let jwt else { return nil }

    guard
        let part = jwt.split(separator: ".").dropFirst().first,
        let payload = Data(base64UrlEncoded: String(part)),
        let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
    else {
        CoreLog.error(#function, error: CoreEvents.jwtParsingError)
        return nil
    }

    return json[Constants.AuthKeys.rtoken] as? String
}
