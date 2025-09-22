//
//  APNSInterface.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

/// Interface for APNs (Apple Push Notification Service) operations.
///
/// Provides method  to get  the APNs token.
public protocol APNSInterface {
    
    /// Retrieves the current APNs token.
    ///
    /// - Parameter completion: Callback with the APNs token as a `String?`, or `nil` if unavailable.
    func getToken(completion: @escaping (String?) -> Void)
}
