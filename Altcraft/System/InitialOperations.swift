//
//  Core.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Performs SDK initialization after network connectivity and foreground state are available.
///
/// Steps:
/// 1) Resets all retry counters.
/// 2) Starts mobile events and profile update pipelines without internal retry.
/// 3) If the push module is active:
///    - Starts subscription processing without retry,
///    - Sends all pending push events,
///    - Triggers token update.
///
/// Notes:
/// - All operations are asynchronous; no completion callback is provided.
/// - Internal retry scheduling is disabled (`enableRetry: false`).
/// - Token debug logging is not affected.
@available(iOSApplicationExtension, unavailable)
func performInitOperations() {
    Task {
        await NetworkMonitor.shared.waitConnected()
        await ForegroundCheck.shared.waitUntilForeground()

        RetryCounters.shared.reset(RetryKey.subscribe)
        RetryCounters.shared.reset(RetryKey.pushEvent)
        RetryCounters.shared.reset(RetryKey.mobileEvent)
        RetryCounters.shared.reset(RetryKey.tokenUpdate)
        RetryCounters.shared.reset(RetryKey.profileUpdate)

        await MobileEvent.shared.enqueueStart(enableRetry: false)
        await ProfileUpdate.shared.enqueueStart(enableRetry: false)
        
        if await TokenManager.shared.pushModuleIsActive() {
            _ = await TokenUpdate.shared.tokenUpdate()
            await PushEvent.shared.sendAllPushEvents()
            await PushSubscribe.shared.enqueueStart(
                enableRetry: false
            )
        }
    }
}
