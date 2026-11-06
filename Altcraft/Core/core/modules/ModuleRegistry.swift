//
//  ModuleRegistry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Stores optional Altcraft SDK modules and dispatches SDK lifecycle events.
///
/// Core SDK does not depend on concrete module implementations. Each optional
/// module registers its queue worker during SDK initialization and receives
/// initialization, clear, and r-token-change events.
///
/// Core's own lifecycle is handled by ``ModuleLifecycle``; the registry
/// notifies it through ``notifyInitialized()``, ``notifyClear()``, and
/// ``notifyRTokenChanged()`` before dispatching to registered modules.
///
/// Mirrors Android `ModuleRegistry`.
@_spi(_Altcraft) public actor ModuleRegistry {
    /// Shared registry instance.
    public static let shared = ModuleRegistry()

    /// Registered modules indexed by their unique identifiers.
    private var modules: [String: AltcraftModule] = [:]

    /// Configurations of optional modules indexed by their identifiers.
    ///
    /// Core stores module configurations without knowing their concrete types;
    /// each registered module resolves and applies its own configuration.
    private var moduleConfigurations: [String: any ModuleConfiguration] = [:]

    /// Whether the initialization (dispatch) phase has already run
    /// in the current process session.
    ///
    /// The initialization dispatch is executed once so a repeated
    /// SDK initialization does not start duplicate pipelines.
    private var initStarted = false
    private var initializationGeneration: UInt64 = 0

    private init() {}

    /// Discovers linked modules that need no explicit configuration, including
    /// stores left by a previous process session.
    func registerLinkedModules() async {
        for name in [
            "AltcraftInAppModuleProvider",
            "AltcraftProfileModuleProvider",
            "AltcraftTargetModuleProvider"
        ] {
            guard let provider = NSClassFromString(
                name
            ) as? any LinkedModuleProvider.Type else {
                continue
            }
            let module = provider.lifecycle
            if modules[module.moduleId] == nil {
                await register(module)
            }
        }
    }

    /// Registers an optional SDK module.
    ///
    /// If a module with the same identifier is already registered,
    /// its implementation is replaced. A pending module configuration,
    /// if any, is validated and applied to the module.
    ///
    /// - Parameter module: Module implementation to register.
    public func register(_ module: AltcraftModule) async {
        modules[module.moduleId] = module
        if let configuration = moduleConfigurations[module.moduleId] {
            await apply(to: module, configuration: configuration)
        }
    }

    /// Removes an optional SDK module from the registry.
    ///
    /// - Parameter moduleId: Unique identifier of the module.
    public func unregister(_ moduleId: String) {
        modules.removeValue(forKey: moduleId)
    }

    /// Stores module configurations, auto-registers modules that provide their
    /// worker, and applies every configuration to its module.
    ///
    /// A configuration whose module is not yet registered is registered
    /// immediately (deterministically, before the initialization dispatch) and
    /// then validated and configured. If a configuration does not provide a
    /// worker, it is only stored and applied later at lazy registration time.
    ///
    /// - Parameter configurations: Module configurations indexed by identifiers.
    public func applyModuleConfigurations(
        _ configurations: [String: any ModuleConfiguration]
    ) async {
        moduleConfigurations = configurations

        for (identifier, configuration) in configurations {
            guard let module = modules[identifier] else {
                guard let worker = configuration.module() else {
                    continue
                }

                modules[worker.moduleId] = worker
                guard await worker.validate(configuration) else {
                    continue
                }
                await worker.configure(configuration)
                continue
            }

            await apply(to: module, configuration: configuration)
        }
    }

    /// Validates a module configuration and applies it to a registered module.
    ///
    /// `configure(_:)` runs only when validation succeeds, so an invalid
    /// configuration never reaches the module's config manager.
    ///
    /// - Parameters:
    ///   - module: Registered module to configure.
    ///   - configuration: Configuration to validate and apply.
    private func apply(
        to module: AltcraftModule,
        configuration: any ModuleConfiguration
    ) async {
        guard await module.validate(configuration) else {
            return
        }
        await module.configure(configuration)
    }

    /// Returns a snapshot of the registered module queue workers.
    ///
    /// Used by the background refresh task to dispatch pending work.
    public func allModules() async -> [AltcraftModule] {
        await registerLinkedModules()
        return Array(modules.values)
    }

    /// Notifies Altcraft SDK that core has been initialized successfully.
    ///
    /// Waits for network connectivity and the first foreground activation,
    /// then executes the initialization dispatch (``notifyInitializedInternal()``).
    /// Runs only once per process session.
    ///
    /// Mirrors Android `ModuleRegistry.notifyInitialized` (gated entry)
    /// delegating to `notifyInitializedInternal`.
    @available(iOSApplicationExtension, unavailable)
    func notifyInitialized() async {
        guard !initStarted else { return }
        initStarted = true
        let generation = initializationGeneration

        await NetworkMonitor.shared.waitConnected()
        await ForegroundCheck.shared.waitUntilForeground()

        guard generation == initializationGeneration else { return }

        await notifyInitializedInternal(generation: generation)
    }

    /// Executes the initialization dispatch: the role-token dispatch-time
    /// re-check, core initialization, and the module initialization phase.
    ///
    /// The re-check runs first (Android parity, the pre-check in
    /// `ModuleRegistry.notifyInitializedInternal`): a change missed at
    /// configuration time because the JWT was not yet available is detected
    /// here and settles before the module initialization phase starts, so
    /// module data processing never races the change notification.
    ///
    /// A role-token change detected by a JWT read while the module
    /// initialization phase is already running (the JWT became available
    /// mid-dispatch) settles after the phase, and the phase is re-run once
    /// so its data processing happens after the last completed change
    /// notification.
    ///
    /// - Parameter generation: Initialization generation snapshot guarding
    ///   the dispatch against a concurrent clear/re-initialization. When
    ///   `nil`, the current generation is snapshotted (unit test entry).
    func notifyInitializedInternal(generation: UInt64? = nil) async {
        let generation = generation ?? initializationGeneration

        // Dispatch-time role-token re-check: the change notification runs
        // inline and settles before the module initialization phase starts.
        await RTokenChange.shared.checkFromInit()

        await ModuleLifecycle.onSdkInitialized()
        guard generation == initializationGeneration else { return }

        let notificationsBefore = await RTokenChange.shared.notificationCount
        for module in modules.values { await module.onSdkInitialized() }

        // Settle a change delivered while the module initialization phase
        // was running and re-run the phase once against the new identity.
        await RTokenChange.shared.waitUntilSettled()
        guard generation == initializationGeneration else { return }
        guard await RTokenChange.shared.hasChanged(
            since: notificationsBefore
        ) else { return }
        for module in modules.values { await module.onSdkInitialized() }
    }

    /// Processes pending operations of every registered queue worker.
    ///
    /// - Parameter enableRetry: If `true`, failed operations schedule local
    ///   retries; if `false`, failures are dropped without retry.
    func processPending(enableRetry: Bool) async {
        for module in modules.values {
            await module.processPending(enableRetry: enableRetry)
        }
    }

    /// Notifies the core and all registered modules that Altcraft SDK data
    /// is being cleared.
    ///
    /// An error in one module does not prevent cleanup of the remaining
    /// registered modules.
    func notifyClear() async {
        await registerLinkedModules()
        initStarted = false
        initializationGeneration &+= 1
        // Open and clear module stores before Core removes the App Group name.
        for module in modules.values {
            await module.onSdkClear()
        }
        await ModuleLifecycle.onSdkClear()
    }

    /// Notifies the core and all registered modules that the SDK rToken
    /// has changed.
    ///
    /// Emits the ``CoreEvents/rTokenChange`` event, restores the core
    /// anonymous session first, and only then dispatches to the registered
    /// modules — mirroring the Android order (`ModuleRegistry.notifyRTokenChanged`:
    /// `ModuleLifecycle.onSdkRTokenChanged`, then modules). Module cleanup and
    /// follow-up requests therefore run against the new identity already.
    func notifyRTokenChanged() async {
        CoreLog.event(#function, event: CoreEvents.rTokenChange)

        await registerLinkedModules()

        await ModuleLifecycle.onSdkRTokenChanged()

        for module in modules.values {
            await module.onSdkRTokenChanged()
        }
    }

    /// Notifies all registered modules that the SDK authentication state
    /// has changed (e.g., user logout).
    ///
    /// Modules drop pending data bound to the previous ACID. An error in one
    /// module does not prevent notification of the remaining modules.
    func notifyAuthStateChanged() async {
        for module in modules.values {
            await module.onAuthStateChanged()
        }
    }

    /// Notifies all registered modules that the process environment has
    /// been reset (e.g., a Notification Service Extension starts a new
    /// delivery in a reused process).
    ///
    /// Modules drop per-process cached state derived from the SDK
    /// configuration. An error in one module does not prevent notification
    /// of the remaining modules.
    func notifyEnvironmentReset() async {
        await registerLinkedModules()
        for module in modules.values {
            await module.onEnvironmentReset()
        }
    }
}
