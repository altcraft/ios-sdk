//
//  Retry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import CoreData

@available(iOSApplicationExtension, unavailable)
private let pushSubscribe  = PushSubscribe.shared
@available(iOSApplicationExtension, unavailable)
private let tokenUpdate    = TokenUpdate.shared
private let mobileEvent    = MobileEvent.shared
private let pushEvent      = PushEvent.shared
private let profileUpdate  = ProfileUpdate.shared
private let networkMonitor = NetworkMonitor.shared

enum RetryKey {
    static let subscribe      = "subscribe"
    static let tokenUpdate    = "tokenUpdate"
    static let pushEvent      = "pushEvent"
    static let mobileEvent    = "mobileEvent"
    static let profileUpdate  = "profileUpdate"
}

/// Thread-safe retry counters container.
final class RetryCounters: @unchecked Sendable {
    static let shared = RetryCounters()

    private let q = DispatchQueue(
        label: "group.altcraft.retry.counters"
    )
    private var values: [String: Int] = [
        RetryKey.subscribe: 0,
        RetryKey.tokenUpdate: 0,
        RetryKey.pushEvent: 0,
        RetryKey.mobileEvent: 0,
        RetryKey.profileUpdate: 0
    ]

    func get(_ key: String) -> Int {
        q.sync { values[key] ?? 0 }
    }

    func increment(_ key: String) {
        q.sync { values[key, default: 0] += 1 }
    }

    func reset(_ key: String) {
        q.sync { values[key] = 0 }
    }
}

/// Retries the push/subscribe flow while under the local retry limit.
@available(iOSApplicationExtension, unavailable)
func pushSubscribeRetry() {
    let counterKey = RetryKey.subscribe
    let attempt = RetryCounters.shared.get(counterKey)

    let work = DispatchWorkItem {
        Task {
            let current = RetryCounters.shared.get(counterKey)
            guard current <= Constants.Retry.maxLocalRetryCount
            else {
                return
            }

            await networkMonitor.performWhenConnected {
                await pushSubscribe.enqueueStart()
                RetryCounters.shared.increment(
                    counterKey
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.subscribeQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the aggregated mobile event flow while under the local retry limit.
func mobileEventRetry() {
    let counterKey = RetryKey.mobileEvent
    let attempt = RetryCounters.shared.get(counterKey)

    let work = DispatchWorkItem {
        Task {
            let current = RetryCounters.shared.get(counterKey)
            guard current <= Constants.Retry.maxLocalRetryCount
            else {
                return
            }

            await networkMonitor.performWhenConnected {
                await mobileEvent.enqueueStart()
                RetryCounters.shared.increment(
                    counterKey
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.mobileEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the aggregated profile update flow while under the local retry limit.
func profileUpdateRetry() {
    let counterKey = RetryKey.profileUpdate
    let attempt = RetryCounters.shared.get(counterKey)

    let work = DispatchWorkItem {
        Task {
            let current = RetryCounters.shared.get(counterKey)
            guard current <= Constants.Retry.maxLocalRetryCount
            else {
                return
            }

            await networkMonitor.performWhenConnected {
                await profileUpdate.enqueueStart()
                RetryCounters.shared.increment(
                    counterKey
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.profileUpdateQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the token update flow if within retry limits.
@available(iOSApplicationExtension, unavailable)
func tokenUpdateRetry() {
    let counterKey = RetryKey.tokenUpdate
    let attempt = RetryCounters.shared.get(counterKey)

    let work = DispatchWorkItem {
        Task {
            let current = RetryCounters.shared.get(counterKey)
            guard current <= Constants.Retry.maxLocalRetryCount
            else {
                return
            }

            await networkMonitor.performWhenConnected {
                _ = await tokenUpdate.tokenUpdateResult(
                    enableRetry: true
                )
                RetryCounters.shared.increment(
                    counterKey
                )
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.tokenUpdateQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Retries the per-entity push event flow if within retry limits.
///
/// - Parameter objectID: The `NSManagedObjectID` of the push event to retry.
func pushEventRetry(objectID: NSManagedObjectID) {
    let counterKey = RetryKey.pushEvent
    let attempt = RetryCounters.shared.get(counterKey)

    let work = DispatchWorkItem {
        Task {
            let current = RetryCounters.shared.get(counterKey)
            guard current <= Constants.Retry.maxLocalRetryCount
            else {
                return
            }

            await networkMonitor.performWhenConnected {
                let context = CoreDataManager.shared.getContext()
                _ = await pushEvent.sendPushEvent(
                    context: context,
                    event: objectID,
                    shouldRetry: true
                )
            
                RetryCounters.shared.increment(
                    counterKey
                )
            }
        }
    }

    let key = objectID.uriRepresentation().absoluteString
    RetryManager.shared.store(key: key, work: work)
    RetryManager.shared.pushEventQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Calculates an exponential backoff delay based on the retry count.
///
/// - Parameter retryCount: Current retry attempt counter.
/// - Returns: Delay in seconds before the next retry attempt.
func delay(retryCount: Int) -> Double {
    pow(Double(Constants.Retry.initialDelay) + 3, Double(retryCount))
}
