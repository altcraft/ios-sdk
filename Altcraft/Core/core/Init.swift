//
//  Init.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
/// Coordinates Altcraft SDK initialization.
@available(iOSApplicationExtension, unavailable)
actor AltcraftInit {

    /// Shared singleton instance.
    internal static let shared = AltcraftInit()

    private init() {}

    /// Initializes the SDK using the provided configuration.
    ///
    /// The configuration is validated in ``ConfigManager/setConfig(_:)``:
    /// an invalid configuration deletes the stored configuration entity,
    /// emits the setup error and aborts initialization before authentication.
    ///
    /// - Parameter configuration: SDK configuration.
    /// - Returns: `true` if initialization completed successfully, otherwise `false`.
    func initSDK(configuration: AltcraftConfiguration) async -> Bool {

        let reservedGate = await InitBarrier.shared.reserve()

        Logger.shared.setStatus(configuration.getEnableLogging())

        await ModuleRegistry.shared.registerLinkedModules()

        let isSet = await ConfigManager.shared.setConfig(configuration)

        guard isSet else {
            await InitBarrier.shared.complete(reservedGate)
            return false
        }

        // Compares the previously stored role token with the new one and
        // notifies modules on change (Android parity, `Init.init` →
        // `RTokenChange.checkRTokenChangedFromInit`).
        await RTokenChange.shared.checkFromConfig()

        await Authenticate.shared.setAuth()

        CoreLog.event(#function, event: CoreEvents.configSet)

        await ModuleRegistry.shared.applyModuleConfigurations(
            configuration.getModuleConfigurations()
        )
        ModuleLifecycle.performInitOperations()

        await InitBarrier.shared.complete(reservedGate)
        return true
    }
}
