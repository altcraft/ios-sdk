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
          let authKey = "JWT_KEY"
          let suiteName = "your_app_group_identifier"
        
          return UserDefaults(suiteName: suiteName)?.string(forKey: authKey)
      }
}

