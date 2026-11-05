//
//  JWTProvider.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import AltcraftCore
import Foundation

/// JWT provider reading from the app group (`JWTInterface`).
class JWTProvider: JWTInterface {
    /// Returns the JWT supplied through the shared app group storage
    /// (`JWTInterface` implementation).
    func getToken() -> String? {
        return UserDefaults(suiteName: NotificationService().appGroupID)?.string(
            forKey: "JWT_KEY"
        )
    }
}
