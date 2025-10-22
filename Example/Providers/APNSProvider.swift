//
//  APNSProvider.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft

class APNSProvider: APNSInterface {
    
    /// Retrieves the current APNs token from local storage.
    func getToken(completion: @escaping (String?) -> Void) {
        let token = getAPNsTokenFromUserDefault()
        completion(token)
    }
}
