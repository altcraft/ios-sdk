//
//  JWTProvider.swift
//  PushService
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft

class JWTProvider: JWTInterface {
    func getToken() -> String? {
        return UserDefaults(suiteName: NotificationService().appGroupID)?.string(forKey: "JWT_KEY")
    }
}
