//
//  TokenDataObjC.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Objective-C–friendly representation of the Swift `TokenData` value.
///
/// Mirrors `TokenData` (provider + token) but uses an `NSObject` subclass so
/// it can be consumed directly from Objective-C code.
///
/// ```objc
/// TokenDataObjC *t = /* ... */;
/// NSString *p = t.provider;
/// NSString *tok = t.token;
/// ```
@objcMembers
public final class TokenDataObjC: NSObject, @unchecked Sendable {
    /// The provider identifier (e.g. `ios-apns`, `ios-firebase`, `ios-huawei`).
    public let provider: String

    /// The raw device push token string.
    public let token: String

    /// Creates a new ObjC token value.
    /// - Parameters:
    ///   - provider: Provider id.
    ///   - token: The device token string.
    public init(provider: String, token: String) {
        self.provider = provider
        self.token = token
        super.init()
    }

    /// Swift -> ObjC factory. Returns `nil` if either `provider` or `token` is empty.
    ///
    /// - Parameter swift: The source Swift `TokenData`.
    /// - Returns: A bridged `TokenDataObjC`, or `nil` when invalid.
    public static func from(_ swift: TokenData?) -> TokenDataObjC? {
        guard let swift, !swift.provider.isEmpty, !swift.token.isEmpty else { return nil }
        return TokenDataObjC(provider: swift.provider, token: swift.token)
    }

    /// ObjC -> Swift converter.
    ///
    /// - Returns: The equivalent Swift `TokenData`, or `nil` if bridged fields are empty.
    public func toSwift() -> TokenData? {
        guard !provider.isEmpty, !token.isEmpty else { return nil }
        return TokenData(provider: provider, token: token)
    }
}
