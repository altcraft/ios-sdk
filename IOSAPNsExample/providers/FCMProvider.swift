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
    
        ///apns token retrieved from userDefault
        let apnsToken = getAPNsTokenDataFromUserDefaults()
        
        ///set the apns token for fcm before requesting the fcm token
        Messaging.messaging().apnsToken = apnsToken
    
       /// Request the FCM token
        Messaging.messaging().token { token, error in
            if error != nil {
                completion(nil)
            } else {
                completion(token)
            }
        }
    }

    ///Delete the FCM token
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
