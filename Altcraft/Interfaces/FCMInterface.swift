//
//  FCMInterface.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Interface for FCM (Firebase Cloud Messaging) operations.
///
/// Provides methods to get and delete the FCM token.
@objc
public protocol FCMInterface: AnyObject {
    
    /// Retrieves the current FCM token.
    ///
    /// - Parameter completion: Callback with the FCM token as a `String?`, or `nil` if unavailable.
    @objc func getToken(completion: @escaping (String?) -> Void)
    
    /// Deletes the FCM token.
    ///
    /// - Parameter completion: Callback with `true` if successful, `false` otherwise.
    @objc func deleteToken(completion: @escaping (Bool) -> Void)
}
