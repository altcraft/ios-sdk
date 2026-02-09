//
//  BackgroundTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import BackgroundTasks
import UIKit

/// Manages a single background task lifecycle.
@available(iOSApplicationExtension, unavailable)
final class AccessToBackground: NSObject {

    /// Shared singleton instance.
    public static let shared = AccessToBackground()

    /// Current background task identifier (`.invalid` if no task is active).
    private var taskID: UIBackgroundTaskIdentifier = .invalid

    /// Serial queue to synchronize access to `taskID`
    /// and prevent parallel start/end of background tasks.
    private let queue = DispatchQueue(
        label: Constants.Queues.accessToBackgroundQueue
    )

    /// Queue-specific key to detect execution on `queue`
    /// and avoid deadlocks when calling `queue.sync`.
    private static let queueKey = DispatchSpecificKey<Void>()

    /// Background task name used for system diagnostics.
    private let name = Constants.bgTaskName

    /// Sets up queue-specific context for safe synchronous access.
    override init() {
        super.init()
        queue.setSpecific(key: Self.queueKey, value: ())
    }

    /// Starts a background task if none is currently active.
    /// Safe to call from any thread.
    func accessToBackground() {
        queue.async { [weak self] in
            guard let self else {
                return
            }
            if self.taskID == .invalid {
                let id = UIApplication.shared.beginBackgroundTask(withName: self.name) {
                    [weak self] in self?.endBackgroundTask()
                }
                guard id != .invalid else { return }; self.taskID = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
                    [weak self] in self?.endBackgroundTask()
                }
            }
        }
    }

    /// Ends the currently active background task immediately.
    /// Can be safely called from any thread, including expiration handler.
    private func endBackgroundTask() {
        if DispatchQueue.getSpecific(key: Self.queueKey) != nil {
            endBackgroundTaskOnQueue()
        } else {
            queue.sync {
                endBackgroundTaskOnQueue()
            }
        }
    }

    /// Performs the actual background task termination.
    /// Must be executed on `queue`.
    private func endBackgroundTaskOnQueue() {
        let id = taskID
        guard id != .invalid else {return}
        taskID = .invalid
        UIApplication.shared.endBackgroundTask(id)
    }
}
