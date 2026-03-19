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
    let completionBox = ClosureBox(completion)
    
    RetryManager.shared.cancelAll()
    
    Task {
        let hasError = userDefault.getDbErrorStatus()
        guard !hasError else {
            event(#function, event: coreDataError)
            await MainActor.run {
                completionBox.invoke()
            }
            return
        }
        
        userDefault.clearSavedToken()
        await userDefault.clearManualToken()
        _ = await clearingDb.deleteAllEntitiesFromDb()
        
        await TokenManager.shared.clearTokens()
        
        RetryCounters.shared.reset(RetryKey.subscribe)
        RetryCounters.shared.reset(RetryKey.pushEvent)
        RetryCounters.shared.reset(RetryKey.mobileEvent)
        RetryCounters.shared.reset(RetryKey.tokenUpdate)
        RetryCounters.shared.reset(RetryKey.profileUpdate)
        
        event(#function, event: sdkCleared)
        
        await MainActor.run {
            completionBox.invoke()
        }
    }
}
