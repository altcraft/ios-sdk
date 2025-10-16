//
//  JWTInterface.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

/// Protocol for providing a JWT token
@objc
public protocol JWTInterface: AnyObject { 
    /// Returns a JWT token (synchronously)
    func getToken() -> String?
}
