//
//  ClearCache.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Completely clears the SDK cache: cancels scheduled retries,
/// removes local database data, clears SDK UserDefaults,
/// resets token state and retry counters,
/// and then calls the completion handler.
///
/// Each registered module clears its own persisted data through
/// ``ModuleRegistry/notifyClear()``; Core clears its own entities.
///
/// Module stores are cleared before Core removes the App Group setting.
/// A Core storage error does not prevent cleanup of the other modules.
///
/// - Parameter completion: A closure called after the clearing flow finishes.
@available(iOSApplicationExtension, unavailable)
func clearCache(completion: @escaping () -> Void) {
    let userDefault = StoredVariablesManager.shared
    let completionBox = ClosureBox(completion)

    RetryManager.shared.cancelAll()

    Task {
        let hasError = userDefault.getDbErrorStatus()
        await ModuleRegistry.shared.notifyClear()
        SDKStateCoordinator.shared.resetState()
        resetAllRetryCount()

        if hasError {
            CoreLog.event(
                #function, event: CoreEvents.coreDataError)

            await MainActor.run {
                completionBox.invoke()
            }
            return
        }

        CoreLog.event(#function, event: CoreEvents.sdkCleared)
        await MainActor.run { completionBox.invoke() }
    }
}
