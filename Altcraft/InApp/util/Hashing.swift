//
//  Hashing.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CryptoKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Computes the SHA-256 digest of a string.
///
/// - Parameter string: Input string.
/// - Returns: Hex-encoded digest.
@available(iOSApplicationExtension, unavailable)
internal func sha256(_ string: String) -> String {
    let digest = SHA256.hash(data: Data(string.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}
