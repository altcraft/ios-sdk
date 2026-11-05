//
//  AccessToBackground.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

/// Abstraction over `UIApplication` background-task bookkeeping.
///
/// Decouples ``AccessToBackground`` from UIKit so unit tests can script
/// begin/end behavior without a running application.
@available(iOSApplicationExtension, unavailable)
protocol BackgroundTaskProviding: Sendable {

    /// Begins a background task and returns its identifier.
    ///
    /// - Parameters:
    ///   - name: Diagnostic task name.
    ///   - expirationHandler: Called by the system shortly before the task's
    ///     allotted time ends.
    /// - Returns: The task identifier, or `.invalid` when no task was started.
    func begin(
        name: String,
        expirationHandler: @escaping @Sendable () -> Void
    ) async -> UIBackgroundTaskIdentifier

    /// Ends the background task with the given identifier.
    func end(_ id: UIBackgroundTaskIdentifier) async
}

/// Real UIKit-backed provider.
@available(iOSApplicationExtension, unavailable)
private struct UIKitBackgroundTaskProvider: BackgroundTaskProviding {

    /// Starts a UIKit background task on the main actor.
    ///
    /// - Parameters:
    ///   - name: Diagnostic task name.
    ///   - expirationHandler: Called by the system shortly before the task's
    ///     allotted time ends.
    /// - Returns: The task identifier, or `.invalid` when no task was started.
    func begin(
        name: String,
        expirationHandler: @escaping @Sendable () -> Void
    ) async -> UIBackgroundTaskIdentifier {
        await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: name) {
                expirationHandler()
            }
        }
    }

    /// Ends the UIKit background task with the given identifier.
    ///
    /// Invalid identifiers are ignored.
    ///
    /// - Parameter id: Identifier returned by `begin(name:expirationHandler:)`.
    func end(_ id: UIBackgroundTaskIdentifier) async {
        guard id != .invalid else { return }

        await MainActor.run {
            UIApplication.shared.endBackgroundTask(id)
        }
    }
}

/// Extends execution time when the app goes to background
/// by managing a single `UIBackgroundTask`.
@available(iOSApplicationExtension, unavailable)
@_spi(_Altcraft) public actor AccessToBackground {
    /// Shared singleton instance.
    public static let shared = AccessToBackground()

    private let name = Constants.bgTaskName
    private let maxLifetime: TimeInterval = 20

    /// Source of background task identifiers; real UIKit in production.
    private let provider: any BackgroundTaskProviding

    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var taskStartUptime: TimeInterval?
    private var autoEndTask: Task<Void, Never>?

    /// `true` while a background-task begin request is in flight.
    ///
    /// `accessToBackground()` suspends while the provider creates the task.
    /// Actor reentrancy would otherwise let a concurrent caller pass the
    /// `taskID == .invalid` check during that suspension and begin a second
    /// task; whichever identifier is stored last would orphan the other and
    /// leak it. The flag is set synchronously before the first suspension
    /// point, so overlapping callers take the early-return path instead.
    private var isBeginning = false

    private init() {
        self.provider = UIKitBackgroundTaskProvider()
    }

    /// Creates an actor over a custom provider (unit tests).
    init(provider: any BackgroundTaskProviding) {
        self.provider = provider
    }

    /// Starts a background task if none is active and none is being started.
    ///
    /// If a task is already active (or a begin request is still in flight),
    /// only the auto-end schedule is refreshed.
    ///
    /// Safe to call from any thread.
    public func accessToBackground() async {
        if isBeginning { return }

        if taskID != .invalid {
            rescheduleAutoEndWithinCap()
            return
        }

        isBeginning = true
        defer { isBeginning = false }

        let id = await provider.begin(name: name) { [weak self] in
            Task { await self?.endBackgroundTask() }
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

        await provider.end(id)
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
            // The timer was cancelled because the task's lifetime was
            // rescheduled; ending the task here would ignore the extension.
            guard !Task.isCancelled else { return }
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
