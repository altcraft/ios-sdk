//
//  JWTManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Singleton manager for handling JWT authentication.
class JWTManager: @unchecked Sendable {

    /// Shared instance of JWTManager.
    static let shared = JWTManager()

    /// Stored JWT provider.
    private var jwtProvider: JWTInterface?

    private init() {}

    /// Registers a JWT provider globally for the SDK.
    ///
    /// - Parameter provider: An implementation of `JWTInterface` that supplies JWT tokens.
    internal func register(_ provider: JWTInterface) {
        self.jwtProvider = provider
    }

    /// Retrieves the current JWT token from the registered provider.
    ///
    /// - Returns: A JWT token as a string, or `nil` if no provider is set.
    func getJWT() -> String? {
        return jwtProvider?.getToken()
    }
}
