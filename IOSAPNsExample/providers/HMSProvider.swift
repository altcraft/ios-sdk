//
//  HMSProvider.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import HmsPushSdk
import Altcraft

class HMSProvider: HMSInterface {

    /// Retrieves the current HMS token using APNs token.
    func getToken(completion: @escaping (String?) -> Void) {
        guard let apnsToken = getAPNsTokenFromUserDefault() else {
            completion(nil)
            return
        }

        let token = HmsInstanceId.getInstance().getToken(apnsToken)
        completion(token)
    }
    
    
    func deleteToken(completion: @escaping (Bool) -> Void) {
        HmsInstanceId.getInstance().deleteToken()
        completion(true)
    }
}
