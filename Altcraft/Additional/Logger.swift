//
//  Logger.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

/// SDK logger that respects user-defined logging preferences.
///
/// - `true`  → logs are printed
/// - `false` → logs are suppressed
/// - `nil`   → logging not configured, one-time hint is printed
final class Logger {

    let userDefault = StoredVariablesManager.shared

    /// Shared singleton instance of the logger.
    static let shared = Logger()

    /// Private initializer to enforce singleton usage.
    private init() {}
    
    /// Sets and persists the logging status for the SDK.
    ///
    /// Updates the in-memory logger state and saves the value to `StoredVariablesManager`.
    func setStatus(status: Bool?) {
        Logger.shared.loggingStatus = status
        StoredVariablesManager.shared.setLoggingStatus(
            enabled: status
        )
    }
    
    /// Current logging status, loaded lazily from `StoredVariablesManager`.
    ///
    /// - `true`  → logging enabled.
    /// - `false` → logging disabled.
    /// - `nil`   → not configured yet; a single integration hint will be printed.
    lazy var loggingStatus: Bool? = {
        userDefault.getLoggingStatus()
    }()

    private let integrationHintLock = NSLock()
    private var integrationHintLogged = false

    /// Logs an SDK message according to the current logging status.
    ///
    /// - Parameter message: The message to be logged.
    func log(_ message: String) {
        switch loggingStatus {
        case .some(true):
            print(message)
        case .some(false):
            return
        case .none:
            logIntegrationHintOnce()
        }
    }

    /// Emits a one-time integration hint explaining how to enable logging.
    ///
    /// Thread-safe: uses a lock to ensure the hint is printed only once.
    private func logIntegrationHintOnce() {
        integrationHintLock.lock()
        let shouldLog = !integrationHintLogged
        if shouldLog {
            integrationHintLogged = true
        }
        integrationHintLock.unlock()

        if shouldLog {
            print(Constants.Log.hintLog)
        }
    }
}
