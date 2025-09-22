//
//  ClearCache.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Clears the cache by deleting all entities from the database and resetting related flags.
///
/// This method performs the following actions:
/// - Cancels all scheduled retry tasks.
/// - Deletes all entities from Core Data.
/// - Resets the push subscription request flag and the saved subscriptions flag to `false`.
/// - Invokes the completion handler after the cache has been fully cleared.
///
/// - Parameter completion: A closure to be executed once the cache clearing process is complete.
func clearCache(completion: @escaping () -> Void) {
    
    let clearingDb = ClearingDb.shared
    let userDefault = StoredVariablesManager.shared
    
    RetryManager.shared.cancelAll()
    
    if !userDefault.getDbErrorStatus() {
        clearingDb.deleteAllEntitiesFromDb { _ in
            userDefault.clearSavedToken()
            userDefault.clearManualToken()
            userDefault.setSubRetryCount(value: 0)
            userDefault.setUpdateRetryCount(value: 0)
            userDefault.setPushEventRetryCount(value: 0)
            TokenUpdate.shared.currentToken = nil
            TokenManager.shared.tokens.ts_removeAll()
            
            event(#function, event: sdkCleared)
            
            completion()
        }
    }
}
