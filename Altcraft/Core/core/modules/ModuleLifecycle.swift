//
//  ModuleLifecycle.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Controls the lifecycle of the Altcraft core module: initialization,
/// cleanup, and SDK rToken change handling.
///
/// Mirrors Android `ModuleLifecycle` for the core module. Optional modules
/// provide their own lifecycle handling through their queue worker.
internal enum ModuleLifecycle {

    /// Performs SDK initialization after network connectivity and foreground
    /// state are available: notifies all registered modules.
    @available(iOSApplicationExtension, unavailable)
    static func performInitOperations() {
        Task {
            await ModuleRegistry.shared.notifyInitialized()
        }
    }

    /// Initializes core module operations.
    ///
    /// Concurrent tasks (each wrapped in a `supervisorScope`-like task):
    /// - schedules the next periodic background refresh;
    /// - processes pending authentication requests.
    ///
    /// A failure in one task does not interrupt the remaining tasks.
    @available(iOSApplicationExtension, unavailable)
    static func onSdkInitialized() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                BackgroundTask.shared.scheduleRefreshIfNeeded()
            }
            group.addTask {
                await Authenticate.shared.enqueueStart(
                    enableRetry: false
                )
            }
            for await _ in group {}
        }
        resetAllRetryCount()
    }

    /// Clears core module state.
    ///
    /// - Cancels all scheduled retries and pending background work.
    /// - Resets the initialization control so the next initialization can run again.
    /// - Removes core SDK data (configuration, authentication, authentication
    ///   requests) and clears the SDK UserDefaults.
    ///
    /// Core Data entities are removed while the App Group setting is still
    /// known: the persistent container is created on the first database
    /// access and binds to the store it selects at that moment. Deleting
    /// entities before the UserDefaults wipe keeps that first access inside
    /// the shared container, so a configuration written by a subsequent
    /// initialization remains visible to app extensions.
    @available(iOSApplicationExtension, unavailable)
    static func onSdkClear() async {
        RetryManager.shared.cancelAll()
        BackgroundTask.shared.cancelScheduled()

        resetAllRetryCount()
        await ClearingRepository.shared.deleteCoreEntities()
        await StoredVariablesManager.shared.clearAllSDKUserDefaults()
        await InitBarrier.shared.reset()
    }

    /// Removes core data bound to the previous rToken.
    static func onSdkRTokenChanged() async {
        await Authenticate.shared.logOut()
    }
}
