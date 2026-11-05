//
//  TargetModuleLifecycle.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Lifecycle controller of the Altcraft target module.
///
/// Processes pending mobile events (targeting). Registered in the
/// ``ModuleRegistry`` during SDK initialization.
final actor TargetModuleLifecycle: AltcraftModule {

    /// Shared instance.
    static let shared = TargetModuleLifecycle()

    /// Unique module identifier.
    let moduleId = TargetConstants.Module.id

    private init() {}

    /// Processes pending mobile events.
    ///
    /// - Parameter enableRetry: If `true`, a failed event schedules a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPending(enableRetry: Bool) async {
        await TargetEventWorker.shared.processPending(
            enableRetry: enableRetry
        )
    }

    /// Target module initialization: processes pending events without retries.
    func onSdkInitialized() async {
        await processPending(enableRetry: false)
    }

    /// Invalidates running delivery and clears persisted operations.
    func onSdkClear() async {
        TargetEventQueues.startQueue.suspend()
        defer { TargetEventQueues.startQueue.resume() }
        await TargetEventQueues.entityQueue.resetAndWait()
        RetryManager.shared.cancel(key: TargetConstants.RetryKey.targetEvent)
        _ = await targetDatabase.deleteAll(
            ofEntityNamed: TargetConstants.EntityNames.targetEventEntity
        )
    }

    /// Clears pending target events when the SDK rToken changes.
    func onSdkRTokenChanged() async { await onSdkClear() }

}

/// Discoverable even when the application has not accessed the module facade.
@objc(AltcraftTargetModuleProvider)
final class TargetModuleProvider: NSObject, LinkedModuleProvider {
    static var lifecycle: any AltcraftModule { TargetModuleLifecycle.shared }
}
