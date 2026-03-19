//
//  BackgroundTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import UIKit

/// Extends execution time when the app goes to background
/// by managing a single `UIBackgroundTask`.
@available(iOSApplicationExtension, unavailable)
actor AccessToBackground {

    /// Shared singleton instance.
    static let shared = AccessToBackground()

    private let name = Constants.bgTaskName
    private let maxLifetime: TimeInterval = 20

    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var taskStartUptime: TimeInterval?
    private var autoEndTask: Task<Void, Never>?

    private init() {}

    /// Starts a background task if none is active.
    ///
    /// If a task is already active, reschedules
    /// the internal auto-end timer.
    ///
    /// Safe to call from any thread.
    func accessToBackground() async {
        if taskID != .invalid {
            rescheduleAutoEndWithinCap()
            return
        }

        let id = await MainActor.run { () -> UIBackgroundTaskIdentifier in
            UIApplication.shared.beginBackgroundTask(withName: name) {
                Task {
                    await AccessToBackground.shared.endBackgroundTask()
                }
            }
        }

        guard id != .invalid else { return }

        taskID = id
        taskStartUptime = ProcessInfo.processInfo.systemUptime
        rescheduleAutoEndWithinCap()
    }

    /// Ends the currently active background task.
    ///
    /// Safe to call from any thread, including
    /// the system expiration handler.
    func endBackgroundTask() async {
        guard taskID != .invalid else { return }

        let id = taskID
        taskID = .invalid
        taskStartUptime = nil

        autoEndTask?.cancel()
        autoEndTask = nil

        await MainActor.run {
            UIApplication.shared.endBackgroundTask(id)
        }
    }

    /// Cancels and reschedules the auto-end timer.
    ///
    /// Ensures the background task ends no later
    /// than `maxLifetime` seconds since start.
    private func rescheduleAutoEndWithinCap() {
        autoEndTask?.cancel()
        autoEndTask = nil

        guard let remaining = remainingLifetime() else {
            return
        }

        autoEndTask = Task {
            let ns = UInt64(remaining * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            await endBackgroundTask()
        }
    }

    /// Calculates remaining task lifetime.
    ///
    /// - Returns: Remaining seconds, or `nil`
    ///   if no task is active.
    private func remainingLifetime() -> TimeInterval? {
        guard taskID != .invalid, let start = taskStartUptime else {
            return nil
        }
        let now = ProcessInfo.processInfo.systemUptime
        return max(0, (start + maxLifetime) - now)
    }
}
