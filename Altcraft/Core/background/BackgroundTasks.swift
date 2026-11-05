//
//  BackgroundTasks.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

#if canImport(BackgroundTasks)
/// Coordinates the lifecycle of the system background refresh task.
private final class BGRefreshTaskCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private let task: BGAppRefreshTask

    private var didComplete = false
    private var isCancelled = false

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    /// Marks the task handle as cancelled; the running work should stop
    /// as soon as possible.
    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    /// Returns `true` while the task is neither cancelled nor completed.
    func isActive() -> Bool {
        lock.lock()
        let active = !isCancelled && !didComplete
        lock.unlock()
        return active
    }

    /// Completes the system background task exactly once.
    ///
    /// - Parameter success: Outcome reported to `BGTaskScheduler`.
    func complete(success: Bool) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }

        didComplete = true
        lock.unlock()

        task.setTaskCompleted(success: success)
    }
}
#endif

#if canImport(BackgroundTasks)
/// Thread-safe holder for the scheduled `BGAppRefreshTaskRequest`.
private final class BGRequestTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var request: BGAppRefreshTaskRequest?

    /// Stores the scheduled request for later inspection.
    ///
    /// - Parameter request: Request submitted to `BGTaskScheduler`.
    func store(_ request: BGAppRefreshTaskRequest) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    /// Removes and returns the stored request, or `nil` when nothing
    /// is stored.
    func clear() -> BGAppRefreshTaskRequest? {
        lock.lock()
        let r = request
        request = nil
        lock.unlock()
        return r
    }
}
#endif

/// Manages periodic background refresh scheduling and execution.
///
/// Notes:
/// - Add your refresh identifier into Info.plist under
///   `Permitted background task scheduler identifiers`.
@available(iOSApplicationExtension, unavailable)
public actor BackgroundTask {
    public static let shared = BackgroundTask()

    private nonisolated static let taskID = Constants.BGTaskID
    private let userDefault = StoredVariablesManager.shared

    #if canImport(BackgroundTasks)
    private nonisolated let requestTracker = BGRequestTracker()
    #endif

    private init() {}

    /// Registers the app refresh task with the system and schedules a refresh request.
    ///
    /// Safe to call multiple times.
    public nonisolated func registerBackgroundTask() {
        #if canImport(BackgroundTasks)
        _ = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskID,
            using: nil
        ) { task in
            CoreLog.event(#function, event: CoreEvents.backgroundTaskRegister)

            guard let bgTask = task as? BGAppRefreshTask else {
                return
            }

            let coordinator = BGRefreshTaskCoordinator(task: bgTask)

            bgTask.expirationHandler = {
                CoreLog.error(#function, error: CoreEvents.backgroundTaskExpired)
                BackgroundTask.shared.scheduleRetry()
                coordinator.cancel()
                coordinator.complete(success: false)
            }

            Task {
                await BackgroundTask.shared.backgroundHandler(
                    coordinator: coordinator
                )
            }
        }
        #endif
        scheduleRetry()
    }

    /// Schedules the next app refresh approximately in 3 hours.
    public nonisolated func scheduleRetry() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 180 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            requestTracker.store(request)
        } catch {
            CoreLog.error(#function, error: error)
        }
        #endif
    }

    /// Schedules a background refresh if not already scheduled.
    ///
    /// Safe to call multiple times.
    public nonisolated func scheduleRefreshIfNeeded() {
        scheduleRetry()
    }

    /// Cancels the currently scheduled background refresh request, if any.
    public nonisolated func cancelScheduled() {
        #if canImport(BackgroundTasks)
        if let request = requestTracker.clear() {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: request.identifier)
        }
        #endif
    }

    #if canImport(BackgroundTasks)
    /// Executes background refresh work sequentially.
    ///
    /// Dispatches pending work to every registered module queue worker.
    /// Stops early if the task is cancelled or expired.
    ///
    /// - Parameter coordinator: Controls task state and completion.
    private func backgroundHandler(
        coordinator: BGRefreshTaskCoordinator
    ) async {
        scheduleRetry()

        let workers = await ModuleRegistry.shared.allModules()

        for worker in workers {
            guard coordinator.isActive() else { return }
            await worker.processPending(enableRetry: false)
        }

        guard coordinator.isActive() else { return }

        CoreLog.event(#function, event: CoreEvents.backgroundTaskCompleted)
        coordinator.complete(success: true)
    }
    #endif
}
