//
//  InAppRetry.swift
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

/// Local retries of the Altcraft in-app module.
@available(iOSApplicationExtension, unavailable)
private let inAppSubscribe = InAppSubscriptionProcess.shared

@available(iOSApplicationExtension, unavailable)
private let inAppEvent = InAppEventProcess.shared

@available(iOSApplicationExtension, unavailable)
private let inAppStatic = InAppStaticProcess.shared

@available(iOSApplicationExtension, unavailable)
private let inAppPlacements = InAppPlacementsProcess.shared

private let networkMonitor = NetworkMonitor.shared

/// Retries the in-app subscription flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
@available(iOSApplicationExtension, unavailable)
func inAppSubscribeRetry() {
    let counterKey = InAppConstants.RetryKey.inAppSubscribe
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= InAppConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await InAppSubscriptionWorker.shared.processPending()
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(InAppConstants.RetryQueues.inAppSubscribe).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the per-entity in-app event flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
///
/// - Parameter objectID: In-app event object identifier.
func inAppEventRetry(objectID: NSManagedObjectID) {
    let counterKey = InAppConstants.RetryKey.inAppEvent
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= InAppConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                let context = inAppDatabase.getContext()

                await inAppEvent.sendInAppEvent(
                    context: context,
                    event: objectID,
                    shouldRetry: true
                )
            }
        }
    }

    let key = objectID.uriRepresentation().absoluteString

    RetryManager.shared.store(key: key, work: work)
    RetryManager.shared.queue(InAppConstants.RetryQueues.inAppEvent).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries loading in-app static resources while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted. A
/// successful load resets the counter for the next failure streak.
@available(iOSApplicationExtension, unavailable)
func inAppStaticRetry() {
    let counterKey = InAppConstants.RetryKey.inAppStatic
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= InAppConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                let staticBundle = await inAppStatic.getInAppStatic()

                if staticBundle != nil {
                    RetryCounters.shared.reset(counterKey)
                }
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(InAppConstants.RetryQueues.inAppStatic).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the in-app placements flow while under the local retry limit.
///
/// The retry closure preserves the identifier created for the initial request,
/// so every attempt belongs to the same logical operation.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
///
/// - Parameter requestId: Identifier shared by all placements request attempts.
@available(iOSApplicationExtension, unavailable)
func inAppPlacementsRetry(
    requestId: String
) {
    let counterKey = InAppConstants.RetryKey.inAppPlacements
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= InAppConstants.Retry.maxLocalRetryCount else {
        // No further retry is scheduled: release trigger workers parked on
        // the placements readiness gate so they never wait indefinitely.
        Task {
            await inAppPlacements.retryBudgetExhausted()
        }
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await inAppPlacements.enqueueStart(
                    requestId: requestId
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(InAppConstants.RetryQueues.inAppPlacements).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}
