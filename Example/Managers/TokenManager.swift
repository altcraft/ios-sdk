//
//  TokenManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import SwiftUI
import AltcraftCore
import AltcraftPush
import AltcraftTarget
import Combine

/// Holds the current push token and provider.
@MainActor
class TokenManager: ObservableObject {
    
    @Published var token: String = ""
    @Published var provider: String = ""

    /// Updates the token with a string value.
    ///
    /// - Parameter deviceToken: Token string.
    func updateToken(with deviceToken: String) {
        self.token = deviceToken
    }

    /// Updates the token using raw APNs data.
    ///
    /// - Parameter deviceToken: Raw device token data.
    func updateToken(with deviceToken: Data) {
        self.token = stringFromDeviceToken(deviceToken: deviceToken) ?? ""
    }

    /// Processes an SDK event and updates the token when the provider is set.
    ///
    /// - Parameter event: SDK event carrying the provider and token.
    func updateToken(with event: Event) {
        guard (event.event as? PushModuleEvents) == .pushProviderSet else {
            return
        }
        
        provider = event.value?["provider"] as? String ?? ""
        
        if let token = event.value?["token"] as? String {
            updateToken(with: token)
        } else {
            updateToken(with: "default apnsToken")
        }
    }

    /// Converts raw device token data to a hex string.
    ///
    /// - Parameter deviceToken: Raw device token data.
    /// - Returns: Hex string, or `nil`.
    private func stringFromDeviceToken(deviceToken: Data) -> String? {
        return deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}

// Global singleton for accessing TokenManager
/// Shared `TokenManager` singleton.
@MainActor
class GlobalTokenManager {static let shared = TokenManager()}

