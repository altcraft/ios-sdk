//
//  Core.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Orchestrates retry-related operations for push and subscription flows.
///
/// Waits for network connectivity and foreground state, then:
/// 1) Resets all retry counters .
/// 2) Starts mobile events processing without internal retry .
/// 3) If the push module is active:
///    - Enqueues subscription processing without internal retry,
///    - Resends all pending push events,
///    - Initiates a token update.
///
/// Notes:
/// - No parameters; this function uses shared singletons.
/// - It does **not** disable token debug logging.
@available(iOSApplicationExtension, unavailable)
func performRetryOperations() {
    NetworkMonitor.shared.performActionWhenConnected {
        ForegroundCheck.shared.isForeground {
            
            subRetryCount = 0
            updateRetryCount = 0
            pushEventRetryCount = 0
            mobileEventRetryCount = 0
            
            
            MobileEvent.shared.enqueueStart(enableRetry: false)
            
            TokenManager.shared.pushModuleIsActive{ active in
                if active {
                    PushSubscribe.shared.enqueueStart(enableRetry: false)
                    PushEvent.shared.sendAllPushEvents()
                    TokenUpdate.shared.tokenUpdate()
                }
            }
        }
    }
}
