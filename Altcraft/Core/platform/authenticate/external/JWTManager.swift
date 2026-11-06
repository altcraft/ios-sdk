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
