//
//  Init.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A  class responsible for initializing the Altcraft SDK.
///
/// This class is used internally and accessed via the `shared` singleton.
@available(iOSApplicationExtension, unavailable)
class AltcraftInit: NSObject {
    
    /// A shared singleton instance of `AltcraftInit`
    ///  used to access SDK initialization logic.
    internal static let shared = AltcraftInit()
    
    /// Initializes the Altcraft SDK with the provided configuration.
    ///
    /// - Parameters:
    ///   - configuration: Optional configuration object. If `nil`, initialization fails.
    ///   - completion: Optional callback invoked on the **main** queue with `true` on success,
    ///                 `false` on failure (including `nil` configuration).
    func initSDK(
        configuration: AltcraftConfiguration?, 
        completion: ((Bool) -> Void)? = nil
    ) {
        guard let config = configuration else {
            errorEvent(#function, error: configIsNotSet)
            completion?(false)
            return
        }
        Logger.shared.setStatus(
            status: config.getEnableLogging()
        )
        setConfig(
            url: config.getApiUrl(),
            rToken:config.getRToken(),
            appInfo: config.getAppInfo(),
            providerPriorityList: config.getProviderPriorityList()
        ) { set in
            if !set {completion?(false); return}
            event(#function, event: configSet)
            performRetryOperations()
            completion?(true)
        }
    }
}
