//
//  AuthenticateJson.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Creates a JSON body for the authorization request.
///
/// - Parameter data: The `AuthRequestData` containing authorization details.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createAuthJSONBody(
    data: RequestModel.AuthRequestData
) -> Data? {
    let keys = Constants.JSONKeys.self

    let json: [String: Any] = [
        keys.acid: data.currentAcid ?? NSNull(),
        keys.startTime: data.startAnonSession
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}
