//
//  AltcraftNSE.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Notification Service Extension facade for Altcraft SDK.
///
/// Provides module-specific NSE functionality (push notifications, rich content, etc.)
/// through a unified interface.
///
/// Mirrors the `AltcraftSDK` entry point style: all members are accessed
/// statically (`AltcraftNSE.setAppGroup(...)`) without a `shared` qualifier.
public final class AltcraftNSE: @unchecked Sendable {

    /// Shared NSE instance.
    public static let shared = AltcraftNSE()

    private init() {}

    // MARK: - App Group

    /// Sets the App Group identifier used for the shared container.
    ///
    /// Call this method before performing any Core Data operations if your
    /// app uses an App Group. This ensures the persistent store is correctly
    /// located in the shared container.
    ///
    /// This method is synchronous and returns only after the App Group setup
    /// has been applied on the internal serial queue.
    ///
    /// The system may reuse a Notification Service Extension process for
    /// several deliveries. To keep every delivery consistent with the
    /// configuration written by the host application, each call also drops
    /// the per-process SDK caches derived from the configuration (Core
    /// config and module configs). As a result, the first configuration
    /// read of every delivery fetches the current value from persistent
    /// storage instead of a value cached by a previous delivery.
    ///
    /// - Parameter groupName: The App Group identifier used for the shared container.
    public static func setAppGroup(groupName: String?) {
        SDKStateCoordinator.shared.setAppGroup(groupName)
        Task {
            await ConfigManager.shared.clearCache()
            await ModuleRegistry.shared.notifyEnvironmentReset()
            if Bundle.main.bundlePath.hasSuffix(".appex") {
                await bootstrapInitGate()
            }
        }
    }

    /// Opens the SDK initialization gate for the current extension process
    /// once a configuration is available in the shared store.
    ///
    /// A Notification Service Extension never runs `initialization`, so the
    /// gate would otherwise stay closed and every operation would wait for
    /// the readiness timeout before proceeding. When the host application
    /// has already written a configuration into the shared container, the
    /// environment is usable: the gate is completed immediately and NSE
    /// flows (target events, profile updates, push processing) start
    /// without delay. Without a stored configuration the gate stays closed
    /// and the flows fail through the regular timeout path.
    ///
    /// Only meaningful inside an app extension; the host application always
    /// goes through the real `initialization` flow.
    @_spi(_Altcraft) public static func bootstrapInitGate() async {
        guard await ConfigManager.shared.getConfig() != nil else {
            return
        }

        let gate = await InitBarrier.shared.current()
        guard await !gate.completed() else {
            return
        }

        await InitBarrier.shared.complete(gate)
    }

    // MARK: - JWT

    /// Registers a JWT provider for use with Altcraft SDK.
    ///
    /// - Parameter provider: The `JWTInterface` implementation used to fetch JWT tokens.
    public static func setJWTProvider(provider: JWTInterface) {
        JWTManager.shared.register(provider)
    }
}
