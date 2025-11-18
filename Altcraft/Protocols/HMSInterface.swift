//
//  HMSInterface.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Protocol for HMS (Huawei Mobile Services) operations.
///
/// Provides methods to get and delete the HMS token.
@objc
public protocol HMSInterface: AnyObject {
    
    /// Retrieves the current HMS token.
    ///
    /// - Parameter completion: Callback with the HMS token as a `String?`, or `nil` if unavailable.
    @objc func getToken(completion: @escaping (String?) -> Void)
    
    /// Deletes the HMS token.
    ///
    /// - Parameter completion: Callback with `true` if successful, `false` otherwise.
    @objc func deleteToken(completion: @escaping (Bool) -> Void)
}
