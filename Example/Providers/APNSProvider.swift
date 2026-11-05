//
//  APNSProvider.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftTarget

/// APNs token provider (`TokenProviderInterface`).
class APNSProvider: APNSInterface {
    
    /// Retrieves the current APNs token from local storage.
    func getToken(completion: @escaping (String?) -> Void) {
        let token = getAPNsTokenFromUserDefault()
        completion(token)
    }
}
