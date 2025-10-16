//
//  PeriodicBackgroundTask.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import UIKit
import BackgroundTasks

/// Manages periodic background refresh scheduling and execution.
///
/// Notes:
/// - Requires iOS 13+ and Background Modes capability.
/// - Add your refresh identifier into Info.plist under `Permitted background task scheduler identifiers`.
@objcMembers
public class BackgroundTask: NSObject {

    /// Background refresh identifier (must match Info.plist).
    let taskID = Constants.BGTaskID

    /// Stored variables facade.
    private let userDefault = StoredVariablesManager.shared

    /// Swift singleton (internal storage).
    internal static let shared = BackgroundTask()

    /// Registers the app refresh task with the system and schedules the first run.
    ///
    /// Safe to call multiple times (system keeps the latest registration).
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

    /// Schedules the next app refresh approximately in 3 hours.
    ///
    /// If submission fails (e.g., identifier not in Info.plist), the error is logged.
    public func scheduleRetry() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 180 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            errorEvent(#function, error: error)
        }
    }

    /// Handles the actual background execution.
    ///
    /// Do not expose this to ObjC, because it contains Swift-only types (`BGAppRefreshTask`).
    func backgroundHandler(task: BGAppRefreshTask) {
        // Always schedule the next one at start, so we have another chance if we time out.
        scheduleRetry()

        task.expirationHandler = {
            errorEvent(#function, error: backgroundTaskExpired)
            self.scheduleRetry()
            task.setTaskCompleted(success: false)
        }

        getContext { context in
            // Reset retry counters for one-pass run (no chained retries in background).
            self.userDefault.setSubRetryCount(value: 0)
            self.userDefault.setUpdateRetryCount(value: 0)
            self.userDefault.setPushEventRetryCount(value: 0)
            self.userDefault.setMobileEventRetryCount(value: 0)

            // One sweep: token → subscribe → mobile events → push events.
            TokenUpdate.shared.tokenUpdate() {
                PushSubscribe.shared.startSubscribe(context: context, enableRetry: false) {
                    MobileEvent.shared.startEventsSend(context: context, enableRetry: false) {
                        PushEvent.shared.sendAllPushEvents(context: context) {
                            event(#function, event: backgroundTaskСompleted)
                            task.setTaskCompleted(success: true)
                        }
                    }
                }
            }
        }
    }
}
