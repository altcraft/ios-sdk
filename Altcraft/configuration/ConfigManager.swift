//
//  ConfigManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Coordinates configuration reads and writes using a dedicated serial queue.
/// Ensures that all reads and writes are serialized so that readers always
/// see the latest saved configuration.
final class ConfigCoordinator {
    static let shared = ConfigCoordinator()
    private init() {}

    private let queue = DispatchQueue(label: Constants.Queues.configStoreQueue)

    /// Saves or updates a configuration entity in Core Data.
    /// The coordinator queue is blocked until the Core Data save finishes,
    /// ensuring subsequent reads will return the fresh configuration.
    ///
    /// Adds a 5-second watchdog:
    /// - If it fires and the app is in background, the wait finishes early (returns `false`).
    /// - If it fires and the app is in foreground, logs `longWaitConfigInstall` and keeps waiting.
    ///
    /// - Parameters:
    ///   - configuration: The configuration to save. If `nil`, the operation fails.
    ///   - completion: Closure returning `true` if the save succeeded, otherwise `false`.
    func saveConfig(
        configuration: AltcraftConfiguration?,
        completion: @escaping (Bool) -> Void
    ) {
        guard let configuration = configuration else {
            errorEvent(#function, error: configIsNotSet)
            completion(false)
            return
        }

        queue.async {
            let sem = DispatchSemaphore(value: 0)
            let state = DispatchQueue(label: Constants.Queues.configStoreQueue)
            var done = false
            var resultFlag = false

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
                state.sync {
                    guard !done else { return }
                    if !ForegroundCheck.shared.isForegroundNow() {
                        done = true; resultFlag = false; sem.signal()
                    } else {
                        errorEvent(#function, error: longWaitConfigInstall)
                    }
                }
            }

            setConfig(
                url: configuration.getApiUrl(),
                rToken: configuration.getRToken(),
                appInfo: configuration.getAppInfo(),
                providerPriorityList: configuration.getProviderPriorityList()
            ) { result in
                state.sync {
                    guard !done else { return }
                    done = true; resultFlag = result; sem.signal()
                }
            }

            sem.wait()
            completion(resultFlag)
        }
    }

    /// Retrieves the current configuration from Core Data.
    ///
    /// - Parameter completion: Closure called with the latest `Configuration?`.
    func loadConfig(_ completion: @escaping (Configuration?) -> Void) {
        queue.async {
            getConfigFromCoreData(completion: completion)
        }
    }
}

/// Retrieves the latest configuration using the `ConfigCoordinator`.
///
/// - Parameter completion: Closure called with the current `Configuration?`.
func getConfig(_ completion: @escaping (Configuration?) -> Void) {
    ConfigCoordinator.shared.loadConfig(completion)
}




