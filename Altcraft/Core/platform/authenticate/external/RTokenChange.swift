//
//  RTokenChange.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Handles role token (rToken) changes.
///
/// Compares the current role token with the previously saved one and notifies
/// the SDK modules about the change. The role token is checked at two points:
/// - after the SDK configuration is installed (``checkFromConfig()``);
/// - every time a JWT is read for authentication (``checkFromJWT(jwt:)``).
///
/// Semantics (Android parity, `RTokenChange`):
/// - a `nil` token is ignored: it is neither saved nor notified;
/// - an unchanged token is ignored;
/// - when a previously saved token exists and the new token differs, all
///   registered modules are notified and the new token is saved;
/// - the first saved token does not trigger the notification.
///
/// The saved token is kept independently of the SDK configuration, so it
/// survives a transition to a `nil` configuration token: a later restoration
/// with a different token is still detected and reported to the modules.
actor RTokenChange {

    /// Shared instance.
    static let shared = RTokenChange()

    private init() {}

    /// Checks for a role token change after the SDK configuration is installed.
    ///
    /// The checked value is the configuration rToken, or the rToken extracted
    /// from the JWT payload when the configuration defines none.
    func checkFromConfig() async {
        let config = try? await Environment.create().config()

        await check(
            newToken: config?.rToken ?? extractRToken(
                jwt: JWTManager.shared.getJWT()
            )
        )
    }

    /// Checks for a role token change in a JWT.
    ///
    /// - Parameter jwt: JWT token, may be `nil`.
    func checkFromJWT(jwt: String?) async {
        await check(
            newToken: extractRToken(jwt: jwt)
        )
    }

    /// Removes the saved role token.
    ///
    /// Called on SDK clear, mirroring Android
    /// `ModuleLifecycle.onSdkClear` → `Preferences.clearCurrentRToken`.
    func clear() {
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }

    /// Compares the role token with the previously saved one.
    ///
    /// Notifies the SDK modules about the change and saves the new token.
    /// The notification runs before the token is saved, mirroring the Android
    /// order. Actor isolation serializes concurrent checks.
    ///
    /// - Parameter newToken: New role token, may be `nil`.
    private func check(newToken: String?) async {
        guard let newToken else { return }

        let oldToken = StoredVariablesManager.shared.getCurrentRToken()

        guard oldToken != newToken else { return }

        if oldToken != nil {
            await ModuleRegistry.shared.notifyRTokenChanged()
        }

        StoredVariablesManager.shared.setCurrentRToken(value: newToken)
    }
}
