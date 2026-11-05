//
//  AuthAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Public facade for authentication operations.
@objcMembers
@objc(PublicAuthFunctions)
@available(iOSApplicationExtension, unavailable)
public final class AuthAPI: NSObject, @unchecked Sendable {

    /// Shared instance.
    public static let shared = AuthAPI()

    /// Authenticates the current SDK user.
    @nonobjc
    public func authenticate() {
        Task {
            await Authenticate.shared.authenticate()
        }
    }

    /// ObjC wrapper for authenticate.
    @available(swift, obsoleted: 1)
    @objc(authenticate)
    public func authenticateObjC() {
        authenticate()
    }

    /// Logs out the current SDK user and restores anonymous auth state.
    @nonobjc
    public func logOut() {
        Task {
            await Authenticate.shared.logOut()
        }
    }

    /// ObjC wrapper for logout.
    @available(swift, obsoleted: 1)
    @objc(logOut)
    public func logOutObjC() {
        logOut()
    }

    /// Returns whether the current SDK user is authenticated.
    ///
    /// Mirrors the Android `AuthAPI.isAuthenticated`.
    ///
    /// - Returns: `true` if the current user tag matches the stored auth state.
    @nonobjc
    public func isAuthenticated() async -> Bool {
        await Authenticate.shared.isAuthenticated()
    }

    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// Mirrors the Android `AuthAPI.setJWTProvider` object function.
    ///
    /// - Parameter provider: The `JWTInterface` implementation used to fetch JWT tokens.
    @nonobjc
    public func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
}
