//
//  JWTProvider.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore

/// JWT provider backed by `JWTManager` (`JWTInterface`).
final class JWTProvider: JWTInterface {
    /// Returns the JWT for the current authentication mode
    /// (`JWTInterface` implementation).
    func getToken()  -> String? {
        let jwt = JWTManager.shared.getJWT()

        return jwt
    }
}
