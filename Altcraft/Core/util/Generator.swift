//
//  Generator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import Security

/// Generates a random 12-character alphanumeric identifier.
///
/// Uses cryptographically secure random bytes from `SecRandomCopyBytes`.
/// When the secure generator fails, falls back to bytes derived from a
/// random UUID; ignoring the error would silently produce an all-zero
/// (non-random) identifier.
///
/// - Returns: Random 12-character string containing digits, uppercase letters,
///   and lowercase letters.
func getNano12() -> String {
    let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
    var randomBytes = [UInt8](repeating: 0, count: 12)

    let status = SecRandomCopyBytes(kSecRandomDefault, 12, &randomBytes)

    if status != errSecSuccess {
        let uuid = UUID().uuidString.utf8
        for i in 0..<12 {
            randomBytes[i] = uuid[uuid.index(uuid.startIndex, offsetBy: i % uuid.count)]
        }
    }

    var result = ""
    for i in 0..<12 {
        let index = Int(randomBytes[i]) % chars.count
        result.append(chars[index])
    }

    return result
}

/// Generates a UUID string.
///
/// - Returns: New UUID string in uppercase canonical format.
func generateUUID() -> String {
    UUID().uuidString
}

/// Returns the current Unix timestamp in milliseconds.
///
/// - Returns: Current time in milliseconds since January 1, 1970 UTC.
@_spi(_Altcraft) public func getCurrentTimeMillis() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
}
