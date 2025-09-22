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

/// Extracts and validates the JWT "matching" claim.
///
/// - Parameter jwt: A JWT string (`header.payload.signature`) containing the claim.
/// - Returns: A `JWTMatching` instance if all required fields are present,
///            otherwise `nil` and triggers `errorEvent` if fields are missing.
///
/// The function:
/// 1. Decodes the JWT payload.
/// 2. Extracts `db_id`, `matching`, and available identifiers (`email`, `phone`, `profile_id`, `field_value`, `subscription_id`).
/// 3. Ensures `db_id` and `matching` are present, and at least one identifier exists.
/// 4. Builds `JWTMatching` with a concatenated `matchingValue` string.
/// Extracts the JWT "matching" claim fields from a token.
///
/// - Parameter jwt: A JWT token string (`header.payload.signature`).
/// - Returns: A tuple of extracted fields, or `nil` if parsing fails.
private func getMatchingFields(jwt: String?) -> JWTData?{
    guard let jwt = jwt else {
        errorEvent(#function, error: jwtIsNil)
        return nil
    }
    guard
        let part = jwt.split(separator: ".").dropFirst().first,
        let payload = Data(base64UrlEncoded: String(part)),
        let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
        let raw = (json[Constants.AuthKeys.matching] as? String)?.data(using: .utf8),
        let dict = try? JSONSerialization.jsonObject(with: raw) as? [String: Any]
    else {
        errorEvent(#function, error: JWTParsingError)
        return nil
    }

    let dbId           = dict[Constants.AuthKeys.dbId] as? Int
    let matching       = dict[Constants.AuthKeys.matching] as? String
    let email          = dict[Constants.AuthKeys.email] as? String
    let phone          = dict[Constants.AuthKeys.phone] as? String
    let profileId      = dict[Constants.AuthKeys.profileId] as? String
    let fieldValue     = dict[Constants.AuthKeys.fieldValue] as? String
    let subscriptionId = dict[Constants.AuthKeys.subscriptionId] as? String
    
    let ids = [email, phone, profileId, fieldValue, subscriptionId]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    validateMatchingFields(dbId: dbId, matching: matching, ids: ids)
    
    guard let dbId = dbId, let matching = matching, !matching.isEmpty, !ids.isEmpty else {
        return nil
    }
    
    let hash = extractJWTDataHash(
        dbId: dbId, matching: matching, value: ids.joined(separator: "/")
    )
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



    
