//
//  TokenManager.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Combine
import Altcraft

@MainActor
class TokenManager: ObservableObject {
    
    @Published var token: String = ""
    @Published var provider: String = ""

    // Function to update the token with a string value
    func updateToken(with deviceToken: String) {
        self.token = deviceToken
    }

    // Function to update the token using Data (from APNs)
    func updateToken(with deviceToken: Data) {
        self.token = stringFromDeviceToken(deviceToken: deviceToken) ?? ""
    }

    // Function to process an event and update the token if necessary
    func updateToken(with event: Altcraft.Event) {
        guard event.eventCode == 201 else { return }
        
        provider = event.value?["provider"] as? String ?? ""
        
        if let token = event.value?["token"] as? String {
            updateToken(with: token)
        } else {
            updateToken(with: "default apnsToken")
        }
    }

    // Convert device token Data to a hex string
    private func stringFromDeviceToken(deviceToken: Data) -> String? {
        return deviceToken.map { String(format: "%02x", $0) }.joined()
    }
}

// Global singleton for accessing TokenManager
@MainActor
class GlobalTokenManager {static let shared = TokenManager()}



