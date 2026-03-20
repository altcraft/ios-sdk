//
//  AltcraftInit.swift
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
    /// - Parameter configuration: SDK configuration. If `nil`, initialization fails.
    /// - Returns: `true` if initialization completed successfully, otherwise `false`.
    func initSDK(configuration: AltcraftConfiguration?) async -> Bool {
        
        let reservedGate = await InitBarrier.shared.reserve()

        guard let config = configuration else {
            errorEvent(#function, error: configIsNotSet)
            await InitBarrier.shared.complete(reservedGate)
            return false
        }

        Logger.shared.setStatus(config.getEnableLogging())

        let isSet = await setConfig(
            url: config.getApiUrl(),
            rToken: config.getRToken(),
            appInfo: config.getAppInfo(),
            providerPriorityList: config.getProviderPriorityList()
        )

        guard isSet else {
            await InitBarrier.shared.complete(reservedGate)
            return false
        }

        event(#function, event: configSet)

        performInitOperations()

        await InitBarrier.shared.complete(reservedGate)
        return true
    }
}
