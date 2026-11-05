//
//  Retry.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Retry primitives shared by all Altcraft modules:
/// retry counters, scheduling helpers, and the core (authentication) retry.
///
/// Only the core (auth) retry key lives here; each module owns its own retry
/// keys in its `*Constants.RetryKey` namespace.
private let networkMonitor = NetworkMonitor.shared

/// Keys for retry counters.
@_spi(_Altcraft) public enum RetryKey {
    public static let auth = "auth"
}

/// Thread-safe retry counters container.
///
/// Generic over any key string. Counters are created lazily on first
/// `increment`; `get` returns `0` for unknown keys. `resetAll` clears every
/// key that has been touched (including the core `auth` key).
@_spi(_Altcraft) public final class RetryCounters: @unchecked Sendable {
    public static let shared = RetryCounters()

    private let q = DispatchQueue(
        label: "group.altcraft.retry.counters"
    )

    private var values: [String: Int] = [
        RetryKey.auth: 0
    ]

    /// Returns the current counter value for the key.
    ///
    /// - Parameter key: Counter key.
    /// - Returns: Current value, or `0` for unknown keys.
    public func get(_ key: String) -> Int {
        q.sync {
            values[key] ?? 0
        }
    }

    /// Atomically increments the counter for the key.
    ///
    /// - Parameter key: Counter key.
    public func increment(_ key: String) {
        q.sync {
            values[key, default: 0] += 1
        }
    }

    /// Atomically increments the counter and returns the new value.
    ///
    /// Combines read and increment into a single synchronized operation so
    /// that error handling and retry scheduling observe one consistent
    /// attempt number (Android parity: atomic `retryCount = retryCount + 1`).
    ///
    /// - Parameter key: Counter key.
    /// - Returns: Counter value after the increment.
    public func incrementAndGet(_ key: String) -> Int {
        q.sync {
            values[key, default: 0] += 1
            return values[key] ?? 0
        }
    }

    /// Resets the counter for the key to zero.
    ///
    /// - Parameter key: Counter key.
    public func reset(_ key: String) {
        q.sync {
            values[key] = 0
        }
    }

    /// Resets all retry counters.
    func resetAll() {
        q.sync {
            for key in values.keys {
                values[key] = 0
            }
        }
    }
}

/// Resets all SDK retry counters.
func resetAllRetryCount() {
    RetryCounters.shared.resetAll()
}

/// Retries the aggregated authentication flow while under the local retry limit.
///
/// Atomic retry model (Android parity): the attempt counter is incremented
/// synchronously at scheduling time, and the backoff delay is derived from
/// the new value. Scheduling stops once the retry limit is exhausted.
func authRetry() {
    let counterKey = RetryKey.auth
    let attempt = RetryCounters.shared.incrementAndGet(counterKey)

    guard attempt <= Constants.Retry.maxLocalRetryCount else {
        return
    }

    let work = DispatchWorkItem {
        Task {
            await networkMonitor.performWhenConnected {
                await Authenticate.shared.enqueueStart()
            }
        }
    }

    RetryManager.shared.store(key: counterKey, work: work)
    RetryManager.shared.authQueue.asyncAfter(
        deadline: .now() + delay(retryCount: attempt),
        execute: work
    )
}

/// Calculates an exponential backoff delay based on retry attempt number.
///
/// Mirrors the effective Android WorkManager backoff (`BackoffPolicy.EXPONENTIAL`,
/// `RETRY_TIME_C_WORK = 5s` clamped by the 10-second `MIN_BACKOFF_MILLIS`):
/// the delay doubles with every attempt — 10, 20, 40, 80, 160 seconds. The
/// formula is shared by every module retry so that all requests use identical
/// backoff.
///
/// - Parameter retryCount: Retry attempt number, starting at 1.
/// - Returns: Delay in seconds before the next retry attempt.
@_spi(_Altcraft) public func delay(retryCount: Int) -> Double {
    Constants.Retry.backoffDelay * pow(2, Double(retryCount - 1))
}
