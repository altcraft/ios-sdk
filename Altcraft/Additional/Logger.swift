//
//  Logger.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Thread-safe facade for SDK logging.
///
/// Delegates all mutable state and logging decisions to `LoggerCore`.
final class Logger: Sendable {
    /// Shared singleton instance.
    static let shared = Logger()

    private let core = LoggerCore()

    private init() {}

    /// Asynchronously logs a message according to the current logging settings.
    ///
    /// - Parameter message: The message to log.
    func log(_ message: String) {
        Task {
            await core.log(message)
        }
    }

    /// Asynchronously updates the logging status.
    ///
    /// - Parameter status: `true` to enable logging, `false` to disable it,
    ///   or `nil` to clear the explicit setting.
    func setStatus(_ status: Bool?) {
        Task {
            await core.setStatus(status)
        }
    }
}

/// Actor that stores logging state and performs actual log output.
actor LoggerCore {
    /// Cached logging status.
    ///
    /// Outer `nil` means the value has not been resolved yet.
    /// Inner `nil` means no explicit setting is stored.
    private var loggingStatus: Bool??

    /// Indicates whether the integration hint has already been printed.
    private var integrationHintLogged = false

    init() {}

    /// Updates and persists the logging status.
    ///
    /// - Parameter status: `true` to enable logging, `false` to disable it,
    ///   or `nil` to clear the stored setting.
    func setStatus(_ status: Bool?) {
        loggingStatus = status
        StoredVariablesManager.shared.setLoggingStatus(enabled: status)
    }

    /// Logs a message if logging is enabled.
    ///
    /// If logging status is undefined, prints the integration hint once.
    ///
    /// - Parameter message: The message to log.
    func log(_ message: String) {
        let status = resolvedLoggingStatus()

        switch status {
        case .some(true):
            print(message)
        case .some(false):
            break
        case .none:
            guard !integrationHintLogged else { return }
            integrationHintLogged = true
            print(Constants.Log.hintLog)
        }
    }

    /// Returns the effective logging status, using cached value when available.
    ///
    /// - Returns: `true` if logging is enabled, `false` if disabled,
    ///   or `nil` if the status is not defined.
    private func resolvedLoggingStatus() -> Bool? {
        if let cached = loggingStatus {
            return cached
        }

        let stored = StoredVariablesManager.shared.getLoggingStatus()
        loggingStatus = stored
        return stored
    }
}
