//
//  AuthStatusManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget
import Combine

/// Tracks and displays the authentication status.
@MainActor
final class AuthStatusManager: ObservableObject {

    @Published var isAuthenticated: Bool

    init() {
        self.isAuthenticated = getInternalAuthStatusFromUserDefaults()
    }

    /// Toggles the current authentication status indicator.
    func toggle() {
        if isAuthenticated {
            AltcraftSDK.auth.logOut()
        } else {
            AltcraftSDK.auth.authenticate()
        }
    }

    /// Updates the authentication status from an SDK event.
    ///
    /// - Parameter event: SDK event carrying the authentication state.
    func updateStatus(with event: Event) {
        guard let sdkEvent = event.event else { return }

        if let core = sdkEvent as? CoreEvents {
            switch core {
            case .authenticateSuccessful:
                saveStatus(true)

            case .userLogOut:
                saveStatus(false)

            case .sdkCleared:
                clearStatus()

            default:
                return
            }
        }
    }

    /// Resets the authentication status indicator to its default.
    func clearStatus() {
        saveStatus(false)
    }

    /// Persists the authentication status to UserDefaults.
    ///
    /// - Parameter status: Current authentication status.
    private func saveStatus(_ status: Bool) {
        self.isAuthenticated = status
        setInternalAuthStatusToUserDefaults(status)
    }
}

/// Shared `AuthStatusManager` singleton.
@MainActor
final class GlobalAuthStatusManager {
    static let shared = AuthStatusManager()
    private init() {}
}
