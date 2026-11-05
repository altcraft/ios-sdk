//
//  TokenData.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A push token paired with the provider that issued it.
///
/// This is the single source of truth for the current device push token.
/// It is serialised to/from `UserDefaults` (JSON) and re-hydrated by
/// `JSONDecoder`. The `provider` field is the id returned by the active
/// token provider (e.g. `"ios-apns"`, `"ios-firebase"`, `"ios-huawei"`).
public struct TokenData: Codable, Hashable, Sendable {
    /// The identifier of the push provider that produced this token.
    public let provider: String

    /// The raw device push token string.
    public let token: String

    /// Creates a new token data value.
    /// - Parameters:
    ///   - provider: Provider id (e.g. `ios-apns`).
    ///   - token: The device token string.
    public init(provider: String, token: String) {
        self.provider = provider
        self.token = token
    }
}
