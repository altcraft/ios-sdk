//
//  Retry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

private let pushSubscribe = PushSubscribe.shared
private let tokenUpdate   = TokenUpdate.shared
private let pushEvent     = PushEvent.shared
private let mobileEvent   = MobileEvent.shared
private let networkMonitor = NetworkMonitor.shared

/// Dispatches retry flows for different request types.
/// - Parameters:
///   - request: Logical function code of the request to retry.
///   - context: Optional Core Data context (used by push event retries only).
///   - event: Optional push event entity (used by push event retries only).
func requestRetry(
    request: String,
    event: NSManagedObjectID? = nil
) {
    switch request {
    case Constants.FunctionsCode.SS:
        localPushSubscribeRetry()
        
    case Constants.FunctionsCode.SU:
        localTokenUpdateRetry()
        
    case Constants.FunctionsCode.PE:
        if let event = event {
            localPushEventRetry(
                objectID: event
            )
        }
        
    case Constants.FunctionsCode.ME:
        localMobileEventRetry()
        
    default:
        print("unknown function")
    }
}

var subRetryCount = 0
var updateRetryCount = 0
var pushEventRetryCount = 0
var mobileEventRetryCount = 0

/// Retries the push/subscribe flow while under the local retry limit.
/// Schedules execution with exponential backoff via `delay(retryCount:)` and,
/// once network becomes available, triggers `PushSubscribe.enqueueStart()`.
/// Note: the retry counter is incremented only after the run is scheduled and the
/// network is confirmed available.
private func localPushSubscribeRetry() {
    let work = DispatchWorkItem {
        if subRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushSubscribe.enqueueStart()
                subRetryCount += 1
            }
        }
    }

    RetryManager.shared.store(key: "subscribe", work: work)
    RetryManager.shared.subscribeQueue.asyncAfter(
        deadline: .now() + delay(retryCount: subRetryCount),
        execute: work
    )
}

/// Retries the aggregated mobile event flow while under the local retry limit.
/// Uses exponential backoff via `delay(retryCount:)` and, when the network is available,
/// triggers `MobileEvent.enqueueStart()`. This is an aggregate run: it fetches and
/// processes all pending mobile events, not a per-entity retry.
private func localMobileEventRetry() {
    let work = DispatchWorkItem {
        if mobileEventRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                mobileEvent.enqueueStart()
                mobileEventRetryCount += 1
            }
        }
    }

    RetryManager.shared.store(key: "mobileEvent", work: work)
    RetryManager.shared.mobileEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: mobileEventRetryCount),
        execute: work
    )
}

/// Retries the "push/update" flow if within retry limits.
/// Uses exponential backoff and triggers `startUpdate()` when network is available.
private func localTokenUpdateRetry() {
    let work = DispatchWorkItem {
        if updateRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                tokenUpdate.startUpdate()
                updateRetryCount += 1
            }
        }
    }

    RetryManager.shared.store(key: "tokenUpdate", work: work)
    RetryManager.shared.tokenUpdateQueue.asyncAfter(
        deadline: .now() + delay(retryCount: updateRetryCount),
        execute: work
    )
}

/// Retries the per-entity "event/push" flow if within retry limits.
/// Uses exponential backoff and triggers `sendPushEvent(context:entity:)` when network is available.
/// - Parameters:
///   - context: Managed object context used to access Core Data.
///   - event: Push event entity to retry.
private func localPushEventRetry(objectID: NSManagedObjectID) {
    let work = DispatchWorkItem {
        if pushEventRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushEvent.sendPushEvent(objectID: objectID)
                pushEventRetryCount += 1
            }
        }
    }

    let key = objectID.uriRepresentation().absoluteString
    RetryManager.shared.store(key: key, work: work)
    RetryManager.shared.pushEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: pushEventRetryCount),
        execute: work
    )
}

/// Calculates an exponential backoff delay based on the retry count.
/// - Parameter retryCount: Current retry attempt counter.
/// - Returns: Delay in seconds before the next retry attempt.
func delay(retryCount: Int) -> Double {
    return pow(Double(Constants.Retry.initialDelay) + 3, Double(retryCount))
}

