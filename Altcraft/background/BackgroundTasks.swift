//
//  PeriodicBackgroundTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit
import BackgroundTasks

/// A class responsible for managing periodic background tasks.
///
/// `PeriodicBackgroundTasks` registers and handles background tasks that need to perform
/// periodic operations in background. It utilizes `BGTaskScheduler` to schedule and manage
/// background tasks, ensuring that specific operations are performed even when the app is in the background.
///
/// - Note: This class assumes that the necessary background modes are enabled in the app's capabilities.
public class BackgroundTask: NSObject {

    /// The identifier used for the background task.
    let taskID = Constants.BGTaskID
    
    /// Provides access to the stored VariablesManager.
    private let userDefault = StoredVariablesManager.shared

    /// The shared singleton instance of `PeriodicBackgroundTasks`.
    internal static let shared = BackgroundTask()

    /// Registers a background task with the system.
    ///
    /// This method registers a task with `BGTaskScheduler` using a specified identifier. The task will be handled
    /// by `backgroundHandler` method when it is executed. It also schedules the next retry of the task.
    ///
    /// - Note: This method should be called during app initialization or when setting up background tasks.
    public func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskID, using: nil
        ) { task in
            event(#function, event: backgroundTaskRegister)
            guard let bgTask = task as? BGAppRefreshTask else {
                return
            }
            self.backgroundHandler(task: bgTask)
        }
        scheduleRetry()
    }

    /// Handles the background task by performing necessary operations.
    ///
    /// - Parameter task: The background task to handle. It must be of type `BGAppRefreshTask`.
    func backgroundHandler(task: BGAppRefreshTask) {
        scheduleRetry()

        task.expirationHandler = {
            errorEvent(#function, error: backgroundTaskExpired)
            self.scheduleRetry()
            task.setTaskCompleted(success: false)
        }

        getContext { context in
            self.userDefault.setSubRetryCount(value: 0)
            self.userDefault.setUpdateRetryCount(value: 0)
            self.userDefault.setPushEventRetryCount(value: 0)
            PushSubscribe.shared.startSubscribe(context: context) {
                TokenUpdate.shared.tokenUpdate() {
                    PushEvent.shared.sendAllPushEvents(context: context) {
                        event(#function, event: backgroundTaskСompleted)
                        task.setTaskCompleted(success: true)
                    }
                }
            }
        }
    }

    /// Schedules the next retry for the background task.
    ///
    /// This method creates a new `BGAppRefreshTaskRequest` with the specified identifier and sets the earliest
    /// begin date for the task to be 3 hours from now. It submits the request to `BGTaskScheduler`.
    ///
    /// - Note: The task will be retried approximately every 3 hours.
    ///
    /// - Throws: An error if the request could not be submitted.
    func scheduleRetry() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 180 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorEvent(#function, error: error)
        }
    }
}




