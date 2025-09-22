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

/// A singleton class that manages starting and ending background tasks,
/// ensuring certain operations can continue running while the app is in the background.
class AccessToBackground: NSObject {
   /// The shared singleton instance of `AccessToBackground`.
   public static let shared = AccessToBackground()
   /// A set that keeps track of active background tasks by their names.
   var activeBackgroundTasks: Set<String> = []
   /// The name used for the background task.
   let name = Constants.bgTaskName

    /// Begins a background task to allow specific operations to continue in the background.
    ///
    /// Requests additional time from the system and sets a timeout to end the task after 29 seconds.
    private func beginBackground() {
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.endBackgroundTask(bgTaskID)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 29) { [weak self] in
            if bgTaskID != .invalid {
                self?.endBackgroundTask(bgTaskID)
            }
        }
    }

    /// Ends a background task with the given task identifier.
    ///
    /// - Parameter backgroundTaskID: The identifier of the task to be ended.
    private func endBackgroundTask(_ backgroundTaskID: UIBackgroundTaskIdentifier) {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        activeBackgroundTasks.remove(name)
    }
    
    /// Grants access to background execution if not already active.
    ///
    /// Starts a new background task only if one with the same name isn't already running.
    func accessToBackground() {
        let backgroundTaskName = name
        if !activeBackgroundTasks.contains(backgroundTaskName) {
            activeBackgroundTasks.insert(backgroundTaskName)
            beginBackground()
        }
    }
}


