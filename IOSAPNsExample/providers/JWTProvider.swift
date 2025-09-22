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
          let authKey = "JWT_KEY"
          let suiteName = appGroup
          return UserDefaults(suiteName: suiteName)?.string(forKey: authKey)
      }
}
