//
//  ProfileRetry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Local retries of the Altcraft profile module.
private let profileUpdate = ProfileUpdateProcess.shared

private let networkMonitor = NetworkMonitor.shared

/// Retries the aggregated profile update flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value — eliminating the async gap between error handling and the
/// counter increment, preventing backoff restarts from the minimal value and
/// retry storms. Scheduling stops once the retry limit is exhausted.
func profileUpdateRetry() {
    let counterKey = ProfileConstants.RetryKey.profileUpdate
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= ProfileConstants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await ProfileUpdateWorker.shared.processPending()
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.queue(ProfileConstants.RetryQueues.profileUpdate).asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}
