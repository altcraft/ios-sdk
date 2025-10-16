//
//  JWTProvider.swift
//  PushService
//
//  Created by andrey on 18.07.2025.
//

import Foundation
import Altcraft

class JWTProvider: JWTInterface {
    func getToken() -> String? {
        let jwtKey = "JWT_KEY"
        
        return UserDefaults(suiteName: NotificationService().appGroupID)?.string(forKey: jwtKey)
    }
}


