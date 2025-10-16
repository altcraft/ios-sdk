//
//  Retry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import CoreData

private let pushSubscribe = PushSubscribe.shared
private let tokenUpdate   = TokenUpdate.shared
private let pushEvent     = PushEvent.shared
private let mobileEvent   = MobileEvent.shared

private let userDefault   = StoredVariablesManager.shared
private let networkMonitor = NetworkMonitor.shared

/// Dispatches retry flows for different request types.
/// - Parameters:
///   - request: Logical function code of the request to retry.
///   - context: Optional Core Data context (used by push event retries only).
///   - event: Optional push event entity (used by push event retries only).
func requestRetry(
    request: String,
    context: NSManagedObjectContext? = nil,
    event: PushEventEntity? = nil
) {
    switch request {
    case Constants.FunctionsCode.SS:
        localPushSubscribeRetry()

    case Constants.FunctionsCode.SU:
        localTokenUpdateRetry()

    case Constants.FunctionsCode.PE:
        localPushEventRetry(context: context, event: event)

    case Constants.FunctionsCode.ME:
        localMobileEventRetry()

    default:
        print("unknown function")
    }
}

/// Retries the "push/subscribe" flow if within retry limits.
/// Uses exponential backoff and triggers `enqueueStartSubscribe()` when network is available.
private func localPushSubscribeRetry() {
    guard let localRetryCount = userDefault.getSubRetryCount() else { return }

    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushSubscribe.enqueueStart(context: nil)
                userDefault.setSubRetryCount(value: localRetryCount + 1)
            }
        }
    }

    RetryManager.shared.store(key: "subscribe", work: work)
    RetryManager.shared.subscribeQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount),
        execute: work
    )
}

/// Retries the "push/update" flow if within retry limits.
/// Uses exponential backoff and triggers `startUpdate()` when network is available.
private func localTokenUpdateRetry() {
    guard let localRetryCount = userDefault.getUpdateRetryCount() else { return }

    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                tokenUpdate.startUpdate()
                userDefault.setUpdateRetryCount(value: localRetryCount + 1)
            }
        }
    }

    RetryManager.shared.store(key: "tokenUpdate", work: work)
    RetryManager.shared.tokenUpdateQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount),
        execute: work
    )
}

/// Retries the per-entity "event/push" flow if within retry limits.
/// Uses exponential backoff and triggers `sendPushEvent(context:entity:)` when network is available.
/// - Parameters:
///   - context: Managed object context used to access Core Data.
///   - event: Push event entity to retry.
private func localPushEventRetry(
    context: NSManagedObjectContext?,
    event: PushEventEntity?
) {
    guard let event = event,
          let context = context,
          let uid = event.uid,
          let type = event.type,
          let localRetryCount = userDefault.getPushEventRetryCount() else {
        return
    }

    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                pushEvent.sendPushEvent(context: context, entity: event)
                userDefault.setPushEventRetryCount(value: localRetryCount + 1)
            }
        }
    }

    let key = "pushEvent-\(uid)-\(type)"
    RetryManager.shared.store(key: key, work: work)
    RetryManager.shared.pushEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount),
        execute: work
    )
}

/// Retries the aggregate "event/mobile" flow if within retry limits (subscribe-like strategy).
/// Uses exponential backoff and triggers `enqueueStart` when network is available.
/// This is not per-entity; processing will fetch and send pending mobile events.
private func localMobileEventRetry() {
    guard let localRetryCount = userDefault.getMobileEventRetryCount() else { return }

    let work = DispatchWorkItem {
        if localRetryCount <= Constants.Retry.maxLocalRetryCount {
            networkMonitor.performActionWhenConnected {
                mobileEvent.enqueueStart(context: nil)

                userDefault.setMobileEventRetryCount(value: localRetryCount + 1)
            }
        }
    }

    RetryManager.shared.store(key: "mobileEvent", work: work)
    RetryManager.shared.mobileEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: localRetryCount),
        execute: work
    )
}

/// Calculates an exponential backoff delay based on the retry count.
/// - Parameter retryCount: Current retry attempt counter.
/// - Returns: Delay in seconds before the next retry attempt.
func delay(retryCount: Int) -> Double {
    return pow(Double(Constants.Retry.initialDelay) + 3, Double(retryCount))
}

