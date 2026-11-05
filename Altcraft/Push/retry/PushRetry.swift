//
//  PushRetry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Local retries of the Altcraft push module.
@available(iOSApplicationExtension, unavailable)
private let pushSubscribe = PushSubscriptionProcess.shared

@available(iOSApplicationExtension, unavailable)
private let tokenUpdate = PushTokenProcess.shared

private let pushEvent = PushEventProcess.shared

private let networkMonitor = NetworkMonitor.shared

/// Retries the push subscription flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
@available(iOSApplicationExtension, unavailable)
func pushSubscribeRetry() {
    let counterKey = PushConstants.RetryKey.pushSubscribe
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= PushConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await PushSubscriptionWorker.shared.processPending(enableRetry: true)
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(PushConstants.RetryQueues.subscribe).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the token update flow while under the local retry limit.
///
/// The retry closure preserves the identifier created for the initial request,
/// so every attempt belongs to the same logical operation.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
///
/// - Parameter requestId: Identifier shared by all token update attempts.
@available(iOSApplicationExtension, unavailable)
func tokenUpdateRetry(
    requestId: String
) {
    let counterKey = PushConstants.RetryKey.tokenUpdate
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= PushConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                _ = await tokenUpdate.tokenUpdateResult(
                    enableRetry: true,
                    requestId: requestId
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(PushConstants.RetryQueues.tokenUpdate).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Registry key for a per-entity push event retry.
///
/// - Parameter objectID: Push event object identifier.
/// - Returns: Stable retry key for the entity.
func pushEventRetryKey(_ objectID: NSManagedObjectID) -> String {
    objectID.uriRepresentation().absoluteString
}

/// Retries the per-entity push event flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
///
/// - Parameter objectID: Push event object identifier.
func pushEventRetry(objectID: NSManagedObjectID) {
    let counterKey = PushConstants.RetryKey.pushEvent
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= PushConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                let context = pushDatabase.getContext()

                _ = await pushEvent.sendPushEvent(
                    context: context,
                    event: objectID,
                    shouldRetry: true
                )
            }
        }
    }

    let key = pushEventRetryKey(objectID)

    RetryManager.shared.store(key: key, work: work)
    RetryManager.shared.queue(PushConstants.RetryQueues.pushEvent).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}
