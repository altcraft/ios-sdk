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
class AltcraftInit: NSObject {
    
    /// A shared singleton instance of `AltcraftInit`
    ///  used to access SDK initialization logic.
    internal static let shared = AltcraftInit()
    
    /// Provides access to the `TokenManager` class.
    private let tokenManager = TokenManager.shared
    
    /// Provides access to the stored VariablesManager.
    private let userDefault = StoredVariablesManager.shared
    
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
        ConfigCoordinator.shared.saveConfig(
            configuration: configuration
        ) { [weak self] result in
            guard let self = self else {
                DispatchQueue.main.async {
                    completion?(false)
                }
                return
            }
            
            if result {
                event(#function, event: configSet)
                if pushModuleIsActive(
                    userDefault: self.userDefault, tokenManager: self.tokenManager
                ) {
                    performPushModuleCheck(
                        userDefault: self.userDefault, tokenManager: self.tokenManager
                    )
                }
                DispatchQueue.main.async { 
                    completion?(true)
                }
            } else {
                DispatchQueue.main.async {
                    completion?(false)
                }
            }
        }
    }
}
