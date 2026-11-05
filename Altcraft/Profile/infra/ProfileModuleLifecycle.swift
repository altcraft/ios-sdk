//
//  ProfileModuleLifecycle.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Lifecycle controller of the Altcraft profile module.
///
/// Processes pending profile updates. Registered in the ``ModuleRegistry``
/// during SDK initialization.
final actor ProfileModuleLifecycle: AltcraftModule {

    /// Shared instance.
    static let shared = ProfileModuleLifecycle()

    /// Unique module identifier.
    let moduleId = ProfileConstants.Module.id

    private init() {}

    /// Processes pending profile updates.
    ///
    /// - Parameter enableRetry: If `true`, a failed update schedules a local
    ///   retry; if `false`, failures are dropped without retry.
    func processPending(enableRetry: Bool) async {
        await ProfileUpdateWorker.shared.processPending(enableRetry: enableRetry)
    }

    /// Profile module initialization: processes pending updates without retries.
    func onSdkInitialized() async {
        await processPending(enableRetry: false)
    }

    /// Invalidates running delivery and clears persisted operations.
    func onSdkClear() async {
        ProfileUpdateQueues.startQueue.suspend()
        defer { ProfileUpdateQueues.startQueue.resume() }
        await ProfileUpdateQueues.entityQueue.resetAndWait()
        RetryManager.shared.cancel(key: ProfileConstants.RetryKey.profileUpdate)
        _ = await profileDatabase.deleteAll(
            ofEntityNamed: ProfileConstants.EntityNames.profileUpdateEntity
        )
    }

    /// Clears pending profile updates when the SDK rToken changes.
    func onSdkRTokenChanged() async { await onSdkClear() }

}

/// Discoverable even when the application has not accessed the module facade.
@objc(AltcraftProfileModuleProvider)
final class ProfileModuleProvider: NSObject, LinkedModuleProvider {
    static var lifecycle: any AltcraftModule { ProfileModuleLifecycle.shared }
}
