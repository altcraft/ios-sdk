//
//  NetworkMonitorTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore

/**
 * NetworkMonitorTests
 *
 * Positive scenarios:
 * - test_1: waitConnected() returns immediately when the network is connected.
 * - test_2: a pending waiter is resumed when connectivity becomes available.
 * - test_3: a cancelled task's waiter is removed and its wait ends immediately.
 * - test_4: a task cancelled before registration ends its wait immediately.
 * - test_5: performWhenConnected skips the action when the task is cancelled.
 *
 */
final class NetworkMonitorTests: IsolatedTestCase {

    // MARK: - Helpers

    /// Runs `body` and fails the test if it does not finish within 5 seconds.
    private func withTimeout<T: Sendable>(
        _ body: @escaping @Sendable () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw TestTimeoutError()
            }
            let first = try await group.next()!
            group.cancelAll()
            _ = try? await group.next()
            return first
        }
    }

    // MARK: - Tests

    /// test_1: waitConnected() returns immediately when the network is connected
    func test_1_waitConnected_returnsImmediately_whenNetworkIsConnected() async throws {
        let monitor = NetworkMonitor(startMonitor: false)
        await monitor.test_setConnected(true)

        try await withTimeout {
            await monitor.waitConnected()
        }

        let waiters = await monitor.test_waiterCount()
        XCTAssertEqual(waiters, 0)
    }

    /// test_2: a pending waiter is resumed when connectivity becomes available
    func test_2_waiter_resumes_whenNetworkBecomesAvailable() async throws {
        let monitor = NetworkMonitor(startMonitor: false)
        await monitor.test_setConnected(false)

        let task = Task { await monitor.waitConnected() }
        try await Task.sleep(nanoseconds: 200_000_000)
        let waiters = await monitor.test_waiterCount()
        XCTAssertEqual(waiters, 1)

        await monitor.test_setConnected(true)

        try await withTimeout { await task.value }
        let waitersAfter = await monitor.test_waiterCount()
        XCTAssertEqual(waitersAfter, 0)
    }

    /// test_3: a cancelled task's waiter is removed and its wait ends immediately
    func test_3_cancelledTask_waiterRemoved_andWaitEndsImmediately() async throws {
        let monitor = NetworkMonitor(startMonitor: false)
        await monitor.test_setConnected(false)

        let task = Task { await monitor.waitConnected() }
        try await Task.sleep(nanoseconds: 200_000_000)
        let waiters = await monitor.test_waiterCount()
        XCTAssertEqual(waiters, 1)

        task.cancel()

        try await withTimeout { await task.value }
        let waitersAfter = await monitor.test_waiterCount()
        XCTAssertEqual(waitersAfter, 0)
    }

    /// test_4: a task cancelled before registration ends its wait immediately
    func test_4_cancelBeforeRegistration_endsWaitImmediately() async throws {
        let monitor = NetworkMonitor(startMonitor: false)
        await monitor.test_setConnected(false)

        let task = Task { await monitor.waitConnected() }
        task.cancel()

        try await withTimeout { await task.value }
        let waiters = await monitor.test_waiterCount()
        XCTAssertEqual(waiters, 0)
    }

    /// test_5: performWhenConnected skips the action when the task is cancelled
    func test_5_performWhenConnected_skipsAction_whenTaskIsCancelled() async throws {
        let monitor = NetworkMonitor(startMonitor: false)
        await monitor.test_setConnected(false)
        let flag = ActionFlag()

        let task = Task {
            await monitor.performWhenConnected {
                flag.set()
            }
        }
        task.cancel()

        try await withTimeout { await task.value }

        XCTAssertFalse(flag.isSet)
        let waiters = await monitor.test_waiterCount()
        XCTAssertEqual(waiters, 0)
    }
}

// MARK: - Supporting Types

/// Timeout error used by the local wait helper.
private struct TestTimeoutError: Error {}

/// Thread-safe flag tracking whether the action was executed.
private final class ActionFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var value = false

    /// Marks the action as executed.
    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    /// `true` when the action was executed.
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
