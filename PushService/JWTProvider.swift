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
        return UserDefaults(suiteName: NotificationService().appGroupID)?.string(forKey: "JWT_KEY")
    }
}
