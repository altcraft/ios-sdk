//
//  PushModuleLifecycle.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Lifecycle controller of the Altcraft push module.
///
/// Processes pending token updates, push events, and push subscriptions.
/// Registered in the ``ModuleRegistry`` during SDK initialization.
@available(iOSApplicationExtension, unavailable)
final actor PushModuleLifecycle: AltcraftModule {

    /// Shared instance.
    static let shared = PushModuleLifecycle()

    /// Unique module identifier.
    let moduleId = PushConstants.Module.id

    private init() {}

    /// Processes pending push operations.
    ///
    /// The pipeline runs only when the push module is active.
    ///
    /// - Parameter enableRetry: If `true`, failed operations schedule a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPending(enableRetry: Bool) async {
        guard await TokenManager.shared.pushModuleIsActive() else {
            return
        }

        _ = await PushTokenWorker.shared.processPending(enableRetry: enableRetry)
        await PushEventWorker.shared.processPending()
        await PushSubscriptionWorker.shared.processPending(enableRetry: enableRetry)
    }

    /// Processes pending push operations awaiting their completion
    /// (background refresh path: the app may be suspended right after the
    /// system task is marked complete, so asynchronously enqueued work would
    /// never run).
    ///
    /// The pipeline runs only when the push module is active.
    ///
    /// - Parameter enableRetry: If `true`, failed operations schedule a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPendingAwaited(enableRetry: Bool) async {
        guard await TokenManager.shared.pushModuleIsActive() else {
            return
        }

        await PushTokenWorker.shared.processPendingAwaited(enableRetry: enableRetry)
        await PushEventWorker.shared.processPendingAwaited(enableRetry: enableRetry)
        await PushSubscriptionWorker.shared.processPendingAwaited(enableRetry: enableRetry)
    }

    /// Push module initialization: processes pending operations without retries.
    func onSdkInitialized() async {
        await processPending(enableRetry: false)
    }

    /// Validates the push module configuration.
    ///
    /// Validation is delegated to ``PushConfigManager/validateConfig(_:)``.
    func validate(_ configuration: any ModuleConfiguration) async -> Bool {
        guard let config = configuration as? PushConfiguration else {
            return true
        }
        return await PushConfigManager.shared.validateConfig(config)
    }

    /// Persists and applies the push module configuration.
    func configure(_ configuration: any ModuleConfiguration) async {
        guard let config = configuration as? PushConfiguration else {
            return
        }
        await PushConfigManager.shared.setConfig(config)
    }

    /// Clears push token state and removes push persistency (subscriptions, events, config).
    ///
    /// Skipped when the Push module's Core Data is in critical state:
    /// the module's failure is isolated and does not affect other modules.
    func onSdkClear() async {
        guard !StoredVariablesManager.shared.getDbErrorStatus(
            module: PushConstants.CoreData.modelName
        ) else {
            PushLog.error(#function, error: CoreEvents.coreDataError)
            return
        }

        await TokenManager.shared.clearTokens()
        await PushStoredVariables.shared.clearAll()
        await PushConfigManager.shared.clearCache()

        _ = await pushDatabase.deleteAll(
            ofEntityNamed: PushConstants.EntityNames.subscribeEntity
        )
        _ = await pushDatabase.deleteAll(
            ofEntityNamed: PushConstants.EntityNames.pushEventEntity
        )
    }

    /// Removes pushes bound to the previous rToken.
    func onSdkRTokenChanged() async {
        _ = await pushDatabase.deleteAll(
            ofEntityNamed: PushConstants.EntityNames.subscribeEntity
        )
    }

    /// Drops the per-process push configuration cache so subsequent reads
    /// observe the current persisted configuration.
    func onEnvironmentReset() async {
        await PushConfigManager.shared.clearCache()
    }
}
