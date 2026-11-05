//
//  Path.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Constructs the full URL string for the authentication request.
///
/// - Parameter apiUrl: The base API URL.
/// - Returns: A complete URL string for the authentication endpoint.
func authURL(_ apiUrl: String) -> String {
    return "\(apiUrl)/profile/authenticate"
}
