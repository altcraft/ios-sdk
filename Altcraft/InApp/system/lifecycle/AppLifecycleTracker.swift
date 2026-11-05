//
//  AppLifecycleTracker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Tracks application lifecycle events used by SDK in-app flows.
@available(iOSApplicationExtension, unavailable)
internal final class AppLifecycleTracker: @unchecked Sendable {

    static let shared = AppLifecycleTracker()

    private let stateQueue = DispatchQueue(
        label: InAppConstants.Queues.lifecycleTrackerQueue
    )

    private var isRegistered = false
    private var openAppTriggered = false

    private init() {}

    /// Registers application lifecycle observers.
    ///
    /// The default open app in-app trigger is fired once
    /// when application becomes active for the first time.
    func register() {
        let shouldRegister = stateQueue.sync { () -> Bool in
            guard !isRegistered else {
                return false
            }

            isRegistered = true
            return true
        }

        guard shouldRegister else {
            return
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// Triggers the default open app in-app event once.
    @objc
    private func applicationDidBecomeActive() {
        let shouldTrigger = stateQueue.sync { () -> Bool in
            guard !openAppTriggered else {
                return false
            }

            openAppTriggered = true
            return true
        }

        guard shouldTrigger else {
            return
        }

        InAppProcTrigger.trigger(
            InAppModel.InAppTrigger(
                name: InAppConstants.InAppDefaultTriggerType.openApp,
                type: .default
            )
        )
    }
}
