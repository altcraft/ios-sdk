//
//  AsyncSemaphore.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Actor-based asynchronous semaphore.
///
/// Limits concurrent access to an asynchronous resource without blocking threads.
@available(iOSApplicationExtension, unavailable)
internal actor AsyncSemaphore {

    /// Maximum number of available permits.
    private let value: Int

    /// Current number of available permits.
    private var available: Int

    /// Continuations waiting for an available permit.
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates an asynchronous semaphore.
    ///
    /// - Parameter value: Maximum number of concurrent permits.
    ///   Values lower than `1` are normalized to `1`.
    init(value: Int) {
        self.value = max(1, value)
        self.available = max(1, value)
    }

    /// Waits until a permit becomes available.
    ///
    /// If a permit is available, it is acquired immediately.
    /// Otherwise, the current task is suspended until `signal()` resumes it.
    func wait() async {
        if available > 0 {
            available -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Releases a permit and resumes the next waiting task if needed.
    ///
    /// If there are suspended tasks, the first waiter is resumed.
    /// Otherwise, the number of available permits is increased up to the maximum value.
    func signal() {
        if let first = waiters.first {
            waiters.removeFirst()
            first.resume()
        } else {
            available = min(available + 1, value)
        }
    }
}

#if DEBUG
@available(iOSApplicationExtension, unavailable)
extension AsyncSemaphore {

    /// Test hook: current number of available permits.
    func test_available() -> Int {
        available
    }

    /// Test hook: current number of waiting tasks.
    func test_waitersCount() -> Int {
        waiters.count
    }
}
#endif
