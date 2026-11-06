//
//  InAppModuleLifecycle.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Lifecycle controller of the Altcraft in-app module.
///
/// Processes pending in-app events, placements, and subscriptions.
/// Registered in the ``ModuleRegistry`` during SDK initialization.
@available(iOSApplicationExtension, unavailable)
final actor InAppModuleLifecycle: AltcraftModule {

    /// Shared instance.
    static let shared = InAppModuleLifecycle()

    /// Unique module identifier.
    let moduleId = InAppConstants.Module.id

    /// Whether the one-time SDK initialization dispatch has already run
    /// for this module in the current process session.
    private var didRunInitDispatch = false

    private init() {}

    /// Processes pending in-app operations.
    ///
    /// - Parameter enableRetry: If `true`, failed operations schedule a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPending(enableRetry: Bool) async {
        await InAppEventWorker.shared.processPending()
        await InAppPlacementsWorker.shared.processPending(enableRetry: enableRetry)
        await InAppSubscriptionWorker.shared.processPending(enableRetry: enableRetry)
    }

    /// Processes pending in-app operations awaiting their completion
    /// (background refresh path: the app may be suspended right after the
    /// system task is marked complete, so asynchronously enqueued work would
    /// never run).
    ///
    /// - Parameter enableRetry: If `true`, failed operations schedule a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPendingAwaited(enableRetry: Bool) async {
        await InAppEventWorker.shared.processPendingAwaited(enableRetry: enableRetry)
        await InAppPlacementsWorker.shared.processPendingAwaited(enableRetry: enableRetry)
        await InAppSubscriptionWorker.shared.processPendingAwaited(enableRetry: enableRetry)
    }

    /// In-app module initialization: processes pending operations without retries.
    func onSdkInitialized() async {
        didRunInitDispatch = true
        Task { @MainActor in
            InAppPushCloseObserver.register()
            await WebViewPrewarmer().prewarm()
        }
        await processPending(enableRetry: false)
    }

    /// Validates the in-app module configuration.
    ///
    /// Validation is delegated to ``InAppConfigManager/validateConfig(_:)``:
    /// an invalid configuration is removed from persistence and the in-app
    /// module emits the corresponding `SDKEvent`.
    func validate(_ configuration: any ModuleConfiguration) async -> Bool {
        guard let config = configuration as? InAppConfiguration else {
            return true
        }
        return await InAppConfigManager.shared.validateConfig(config)
    }

    /// Persists and applies the in-app module configuration.
    func configure(_ configuration: any ModuleConfiguration) async {
        guard let config = configuration as? InAppConfiguration else {
            return
        }
        await InAppConfigManager.shared.setConfig(config)

        if didRunInitDispatch {
            await processPending(enableRetry: false)
        }
    }

    /// Authentication state change: drops pending in-app subscriptions
    /// bound to the previous ACID.
    func onAuthStateChanged() async {
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppSubscribeEntity
        )
    }

    /// In-app module cleanup: removes persisted in-app entities.
    ///
    /// Skipped when the In-App module's Core Data is in critical state:
    /// the module's failure is isolated and does not affect other modules.
    func onSdkClear() async {
        guard !StoredVariablesManager.shared.getDbErrorStatus(
            module: InAppConstants.CoreData.modelName
        ) else {
            InAppLog.error(#function, error: CoreEvents.coreDataError)
            return
        }

        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppSubscribeEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppEventEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppsEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppStaticEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.personalPolicyEntity
        )
        await InAppConfigManager.shared.clearCache()
        await InAppStoredVariables.shared.clear()
        await InAppPlacementsProcess.shared.reset()
        await InAppProcTrigger.clear()

        InAppVariables.shared.reset()
    }

    /// Handles an SDK rToken change in the in-app module.
    ///
    /// Mirrors Android `inapp.ModuleLifecycle.onSdkRTokenChanged`:
    /// invalidates delayed presentations, resets session state, cancels
    /// one-time in-flight retries, clears data bound to the previous rToken
    /// (every in-app table except the module configuration, including the
    /// cached subscription status), re-arms the placements readiness gate,
    /// and requests fresh placements for the new resource.
    ///
    /// Queued triggers and the trigger worker are preserved (Android parity,
    /// `PresentationGate.invalidate` keeps the trigger LIFO queue): a worker
    /// parked on the re-armed placements gate stays parked and processes its
    /// queued triggers once the fresh placements arrive.
    ///
    /// Skipped when the In-App module's Core Data is in critical state:
    /// the module's failure is isolated and does not affect other modules.
    func onSdkRTokenChanged() async {
        guard !StoredVariablesManager.shared.getDbErrorStatus(
            module: InAppConstants.CoreData.modelName
        ) else {
            InAppLog.error(#function, error: CoreEvents.coreDataError)
            return
        }

        // Invalidate delayed presentations: presentations scheduled before
        // the change must not run afterwards. Queued triggers and the
        // trigger worker are intentionally kept — they are processed with
        // the fresh placements requested below.
        await DelayTask.shared.cancelAll()

        // Reset session-scoped display counters.
        InAppVariables.shared.reset()

        // Cancel one-time in-flight retries (Android parity, cancelling
        // one-time worker tags). Per-entity event retries are keyed by
        // object identifier and self-neutralize after the entity wipe below.
    
        RetryManager.shared.cancel(key: InAppConstants.RetryKey.inAppEvent)
        RetryManager.shared.cancel(key: InAppConstants.RetryKey.inAppStatic)
        RetryManager.shared.cancel(key: InAppConstants.RetryKey.inAppSubscribe)
        RetryManager.shared.cancel(key: InAppConstants.RetryKey.inAppPlacements)

        // Clear data bound to the previous rToken: all in-app entities
        // except the module configuration (Android `clearDataExceptConfig`).
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppSubscribeEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppEventEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppsEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppStaticEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.inAppEntity
        )
        _ = await inAppDatabase.deleteAll(
            ofEntityNamed: InAppConstants.EntityNames.personalPolicyEntity
        )
        await InAppSubStateDAO.clearInAppSubStateData()

        // Re-arm the placements readiness gate so triggers scheduled after
        // the change wait for fresh placement data.
        await InAppPlacementsProcess.shared.reset()

        // Request fresh placements for the new resource.
        await InAppPlacementsProcess.shared.requestPlacements()
    }

    /// Drops the per-process in-app configuration cache so subsequent reads
    /// observe the current persisted configuration.
    func onEnvironmentReset() async {
        await InAppConfigManager.shared.clearCache()
    }
}

/// Discovers the in-app module at SDK initialization time.
///
/// Mirrors Android, where the in-app module registers itself during
/// application startup (AndroidX Startup initializer) and therefore runs even
/// when the host application provides no explicit `inAppConfig`. Without
/// registration the module would never be initialized and would not request
/// placements, subscriptions, or events.
@objc(AltcraftInAppModuleProvider)
final class InAppModuleProvider: NSObject, LinkedModuleProvider {
    static var lifecycle: any AltcraftModule { InAppModuleLifecycle.shared }
}
