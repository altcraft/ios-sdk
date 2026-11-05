//
//  TargetRetry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Local retries of the Altcraft target module.
private let mobileEvent = TargetEventProcess.shared

private let networkMonitor = NetworkMonitor.shared

/// Retries the aggregated mobile event flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value — eliminating the async gap between error handling and the
/// counter increment, preventing backoff restarts from the minimal value and
/// retry storms. Scheduling stops once the retry limit is exhausted.
func mobileEventRetry() {
    let counterKey = TargetConstants.RetryKey.targetEvent
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= TargetConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await TargetEventWorker.shared.processPending()
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(TargetConstants.RetryQueues.targetEvent).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}
