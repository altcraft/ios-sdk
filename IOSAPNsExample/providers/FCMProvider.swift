//
//  FCMProvider.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import FirebaseMessaging
import Altcraft

class FCMProvider: FCMInterface {
    
    /// Retrieves the current FCM token.
    func getToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if error != nil {
                completion(nil)
            } else {
                completion(token)
            }
        }
    }

    /// Deletes the current FCM token.
    func deleteToken(completion: @escaping (Bool) -> Void) {
        Messaging.messaging().deleteToken { error in
            if error != nil {
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
