//
//  AuthManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CryptoKit

/// Retrieves the current user tag from configuration using either JWT or a resource token.
///
/// - Parameter completion: A closure that receives the user tag string, or `nil` if unavailable.
func getUserTag(completion: @escaping (String?) -> Void) {
    getConfig { config in
        guard let config = config else {
            errorEvent(#function, error: configIsNil)
            completion(nil)
            return
        }
        completion(config.rToken ?? getMatchingFields(
            jwt: JWTManager.shared.getJWT()
        )?.hash)
    }
}

/// Computes a SHA-256 hash of the JSON string built from matching claim data.
///
/// - Parameters:
///   - dbId: Database ID used for matching.
///   - matching: Matching method (e.g. "push_sub").
///   - matchingValue: Concatenated string of matching identifiers.
/// - Returns: Hex-encoded SHA-256 hash string.
private func extractJWTDataHash(dbId: Int, matching: String, value: String) -> String {
    let jsonString = matchingAsString(dbId: dbId, matching: matching, value: value)
    let data = Data(jsonString.utf8)
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
}

/// Extracts and validates the JWT "matching" claim and normalizes it
/// using the same field order  (email / phone / profile_id / field_name / field_value / provider / subscription_id).
///
/// - Parameter jwt: A JWT string (`header.payload.signature`) containing the claim.
/// - Returns: `JWTData` if parsing and validation succeed; otherwise `nil` and emits an error.
private func getMatchingFields(jwt: String?) -> JWTData? {
    guard let jwt = jwt else {
        errorEvent(#function, error: jwtIsNil)
        return nil
    }

    // Decode JWT payload (Base64URL)
    guard
        let part = jwt.split(separator: ".").dropFirst().first,
        let payload = Data(base64UrlEncoded: String(part)),
        let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
        // The `matching` claim inside payload is itself a JSON string → parse again
        let raw = (json[Constants.AuthKeys.matching] as? String)?.data(using: .utf8),
        let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
    else {
        errorEvent(#function, error: JWTParsingError)
        return nil
    }
    
    /// Safely converts a value to `Int` .
    func intValue(_ any: Any?) -> Int? {
        switch any {
        case let n as NSNumber: return n.intValue
        case let i as Int:      return i
        case let s as String:   return Int(s)
        default:                return nil
        }
    }

    /// Safely converts a value to a trimmed non-empty `String`.
    func stringValue(_ any: Any?) -> String? {
        switch any {
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        case let n as NSNumber:
            return n.stringValue
        default:
            return nil
        }
    }

    // Required fields
    let dbId     = intValue(dict[Constants.AuthKeys.dbId])
    let matching = stringValue(dict[Constants.AuthKeys.matching])

    // Optional identifiers
    let email          = stringValue(dict[Constants.AuthKeys.email])
    let phone          = stringValue(dict[Constants.AuthKeys.phone])
    let profileId      = stringValue(dict[Constants.AuthKeys.profileId])
    let fieldName      = stringValue(dict[Constants.AuthKeys.fieldName])
    let fieldValue     = stringValue(dict[Constants.AuthKeys.fieldValue])
    let provider       = stringValue(dict[Constants.AuthKeys.provider])
    let subscriptionId = stringValue(dict[Constants.AuthKeys.subscriptionId])

    let parts = [email, phone, profileId, fieldName, fieldValue, provider, subscriptionId]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

    // Validation: db_id and matching are required, at least one identifier must exist
    validateMatchingFields(dbId: dbId, matching: matching, ids: parts)
    guard let dbId = dbId, let matching = matching, !parts.isEmpty else {
        return nil
    }

    // Build the same concatenated matchingValue as Android
    let matchingValue = parts.joined(separator: "/")


    let hash = extractJWTDataHash(dbId: dbId, matching: matching, value: matchingValue)
    return JWTData(jwt: jwt, hash: hash, matching: matching)
}

/// Validates JWT matching fields and triggers an error event if required fields are missing.
///
/// - Parameters:
///   - dbId: The database ID field.
///   - matching: The matching method.
///   - ids: The list of collected matching identifiers.
private func validateMatchingFields(
    dbId: Int?,
    matching: String?,
    ids: [String]
) {
    var missing: [String] = []

    if dbId == nil { missing.append(Constants.AuthKeys.dbId) }
    if (matching?.isEmpty ?? true) { missing.append(Constants.AuthKeys.matching) }
    if ids.isEmpty { missing.append(Constants.AuthKeys.matchingID) }

    if !missing.isEmpty {
        let error = (542, "matching claim does not contain: \(missing.joined(separator: ", "))")
        errorEvent(#function, error: error)
    }
}

/// Retrieves the authentication header and the matching token.
///
/// - Parameters:
///   - rToken: The resource token used if JWT is unavailable. This can be `nil` or a valid string.
/// - Returns: A tuple containing the authentication header (Bearer token) and matching token (`matchingMode`),
///  or `nil` if both are unavailable.
func getAuthData(rToken: String?) -> (String, String)? {
    if let rToken = rToken, !rToken.isEmpty {
        return ("Bearer rtoken@\(rToken)", rToken)
    } else {
        if let fields = getMatchingFields(jwt: JWTManager.shared.getJWT()){
            return ("Bearer \(fields.jwt)", fields.matching)
        }else { return nil }
    }
}



    
