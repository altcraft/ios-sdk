//
//  Core.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Performs a check and update for the push token, and handles any pending push/subscribe requests.
///
/// This function disables token debug logging, resets all retry counters,
/// and initiates a token update process. If the token update is not required
/// or completes successfully, the function proceeds to check for any pending
/// push or subscribe requests. Simultaneously, it attempts to resend all
/// pending push event requests if any exist.
///
/// - Parameters:
///   - userDefault: The instance responsible for managing stored retry counters.
///   - tokenManager: The token manager used to update the push token and disable logs.
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
