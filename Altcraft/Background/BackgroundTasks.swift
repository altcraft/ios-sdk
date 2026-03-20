//
//  PeriodicBackgroundTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//

import Foundation
import UIKit

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

#if canImport(BackgroundTasks)
private final class BGRefreshTaskCoordinator: @unchecked Sendable {
    private let lock = NSLock()
    private let task: BGAppRefreshTask

    private var didComplete = false
    private var isCancelled = false

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    func isActive() -> Bool {
        lock.lock()
        let active = !isCancelled && !didComplete
        lock.unlock()
        return active
    }

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

    private init() {}

    /// Registers the app refresh task with the system and schedules a refresh request.
    ///
    /// Safe to call multiple times.
    public nonisolated func registerBackgroundTask() {
        _ = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskID,
            using: nil
        ) { task in
            event(#function, event: backgroundTaskRegister)

            guard let bgTask = task as? BGAppRefreshTask else { return }

            let coordinator = BGRefreshTaskCoordinator(task: bgTask)

            bgTask.expirationHandler = {
                errorEvent(#function, error: backgroundTaskExpired)
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

        scheduleRetry()
    }

    /// Schedules the next app refresh approximately in 3 hours.
    public nonisolated func scheduleRetry() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 180 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorEvent(#function, error: error)
        }
    }

    #if canImport(BackgroundTasks)
    /// Executes background refresh work sequentially.
    ///
    /// Stops early if the task is cancelled or expired.
    ///
    /// - Parameter coordinator: Controls task state and completion.
    private func backgroundHandler(
        coordinator: BGRefreshTaskCoordinator
    ) async {
        scheduleRetry()

        _ = await TokenUpdate.shared.tokenUpdate(enableRetry: false)

        guard coordinator.isActive() else { return }
        await PushSubscribe.shared.enqueueStart(enableRetry: false)

        guard coordinator.isActive() else { return }
        await MobileEvent.shared.enqueueStart(enableRetry: false)

        guard coordinator.isActive() else { return }
        await ProfileUpdate.shared.enqueueStart(enableRetry: false)

        guard coordinator.isActive() else { return }
        await PushEvent.shared.sendAllPushEvents()

        guard coordinator.isActive() else { return }

        event(#function, event: backgroundTaskCompleted)
        coordinator.complete(success: true)
    }
    #endif
}
