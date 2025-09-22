//
//  APNSInterface.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

/// Interface for FCM (Firebase Cloud Messaging) operations.
///
/// Provides methods to get and delete the FCM token.
public protocol FCMInterface {
    
    /// Retrieves the current FCM token.
    ///
    /// - Parameter completion: Callback with the FCM token as a `String?`, or `nil` if unavailable.
    func getToken(completion: @escaping (String?) -> Void)
    
    /// Deletes the FCM token.
    ///
    /// - Parameter completion: Callback with `true` if successful, `false` otherwise.
    func deleteToken(completion: @escaping (Bool) -> Void)
}
