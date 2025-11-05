//
//  ClearCache.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Completely clears the SDK cache: cancels all scheduled retries,
/// removes local data, resets internal counters and token data,
/// and then calls the provided completion handler.
///
/// If the database is in an invalid state, the clearing process is skipped
/// and the completion handler is not called.
///
/// - Parameter completion: A closure called after the cache has been successfully cleared.
@available(iOSApplicationExtension, unavailable)
func clearCache(completion: @escaping () -> Void) {
    
    let clearingDb = ClearingDb.shared
    let userDefault = StoredVariablesManager.shared
    
    RetryManager.shared.cancelAll()
    
    if !userDefault.getDbErrorStatus() {
        clearingDb.deleteAllEntitiesFromDb { _ in
            
            subRetryCount = 0
            updateRetryCount = 0
            pushEventRetryCount = 0
            mobileEventRetryCount = 0
            userDefault.clearSavedToken()
            userDefault.clearManualToken()
            TokenUpdate.shared.currentToken = nil
            TokenManager.shared.tokens.ts_removeAll()
            
            event(#function, event: sdkCleared)
            
            completion()
        }
    }
}
