//
//  JWTProvider.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft

class JWTProvider: JWTInterface {
    func getToken() -> String? {
        JWTManager.shared.getJWT()
    }
}
