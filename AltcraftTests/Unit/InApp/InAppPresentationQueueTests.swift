//
//  InAppPresentationQueueTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
 * InAppPresentationQueueTests
 *
 * Positive scenarios:
 *  - test_1: first waitForTurn returns immediately.
 *  - test_2: second waitForTurn blocks until first finishes.
 *  - test_3: finishPresentation releases to next waiter.
 *  - test_4: waiters are served in FIFO order.
 *  - test_5: finishPresentation with no waiters resets state.
 *
 * Edge scenarios:
 *  - test_6: multiple consecutive waitForTurn without finish queues correctly.
 *  - test_7: a cancelled waiter is removed and its wait ends immediately.
 *  - test_8: a task cancelled before registration ends its wait immediately.
 *  - test_9: a cancelled waiter does not break the slot handoff to the next waiter.
 */
final class InAppPresentationQueueTests: XCTestCase {

    private let queue = InAppPresentationQueue.shared

    private func waitShort(_ seconds: TimeInterval = 0.02) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Runs `body` and fails the test if it does not finish within 5 seconds.
    private func withTimeout<T: Sendable>(
        _ body: @escaping @Sendable () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw PresTimeoutError()
            }
            guard let first = try await group.next() else {
                XCTFail("withTimeout: task group returned no result")
                throw PresTimeoutError()
            }
            group.cancelAll()
            _ = try? await group.next()
            return first
        }
    }

    private func waitAsync(description: String = "async", timeout: TimeInterval = 2, _ work: @escaping () async -> Void) {
        let exp = expectation(description: description)
        Task {
            await work()
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        waitAsync {
            await self.queue.finishPresentation()
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// test_1: first waitForTurn returns immediately
    func test_1_firstWaitForTurn_returnsImmediately() async {
        let start = Date()
        await queue.waitForTurn()
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.5)
    }

    /// test_2: second waitForTurn blocks until first finishes
    func test_2_secondWaitForTurn_blocksUntilFirstFinishes() async {
        await queue.waitForTurn()

        let secondEntered = PresFlag()
        let task = Task {
            await queue.waitForTurn()
            secondEntered.mark()
        }

        await waitShort(0.05)
        XCTAssertFalse(secondEntered.isSet)

        await queue.finishPresentation()

        await waitShort(0.05)
        XCTAssertTrue(secondEntered.isSet)
    }

    /// test_3: finishPresentation releases to next waiter
    func test_3_finishPresentation_releasesNextWaiter() async {
        await queue.waitForTurn()

        let released = PresFlag()
        let task = Task {
            await queue.waitForTurn()
            released.mark()
        }

        await waitShort(0.02)
        XCTAssertFalse(released.isSet)

        await queue.finishPresentation()
        await waitShort(0.05)
        XCTAssertTrue(released.isSet)
    }

    /// test_4: waiters are served in FIFO order
    func test_4_waiters_servedInFIFOOrder() async {
        await queue.waitForTurn()

        let order = PresOrderedInts()

        let t1 = Task {
            await queue.waitForTurn()
            order.add(1)
        }
        await waitShort(0.01)

        let t2 = Task {
            await queue.waitForTurn()
            order.add(2)
        }
        await waitShort(0.01)

        let t3 = Task {
            await queue.waitForTurn()
            order.add(3)
        }
        await waitShort(0.01)

        await queue.finishPresentation()
        await waitShort(0.02)
        await queue.finishPresentation()
        await waitShort(0.02)
        await queue.finishPresentation()

        await waitShort(0.05)
        XCTAssertEqual(order.allValues, [1, 2, 3])
    }

    /// test_5: finishPresentation with no waiters resets state
    func test_5_finishPresentation_noWaiters_resetsState() async {
        await queue.waitForTurn()
        await queue.finishPresentation()

        let nextEntered = PresFlag()
        let task = Task {
            await queue.waitForTurn()
            nextEntered.mark()
        }

        await waitShort(0.05)
        XCTAssertTrue(nextEntered.isSet)
    }

    /// test_6: multiple consecutive waitForTurn without finish queues correctly
    func test_6_multipleWaitForTurn_queuesCorrectly() async {
        await queue.waitForTurn()

        let counter = PresCounter()

        for _ in 0..<3 {
            Task {
                await queue.waitForTurn()
                counter.inc()
            }
        }

        await waitShort(0.05)
        XCTAssertEqual(counter.count, 0)

        await queue.finishPresentation()
        await waitShort(0.02)
        XCTAssertEqual(counter.count, 1)

        await queue.finishPresentation()
        await waitShort(0.02)
        XCTAssertEqual(counter.count, 2)

        await queue.finishPresentation()
        await waitShort(0.02)
        XCTAssertEqual(counter.count, 3)
    }

    /// test_7: a cancelled waiter is removed and its wait ends immediately
    func test_7_cancelledWaiter_removedAndResumedImmediately() async throws {
        // Holder keeps the slot busy while the waiter queues up.
        let holder = Task {
            await queue.waitForTurn()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await queue.finishPresentation()
        }
        await waitShort(0.05)

        let waiter = Task { await queue.waitForTurn() }
        await waitShort(0.05)

        let count = await queue.test_waiterCount()
        XCTAssertEqual(count, 1)

        waiter.cancel()

        // The wait must end immediately, long before the holder's 1s window.
        try await withTimeout { await waiter.value }

        let remaining = await queue.test_waiterCount()
        XCTAssertEqual(remaining, 0)

        await holder.value
    }

    /// test_8: a task cancelled before registration ends its wait immediately
    func test_8_cancelBeforeRegistration_endsWaitImmediately() async throws {
        let holder = Task {
            await queue.waitForTurn()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await queue.finishPresentation()
        }
        await waitShort(0.05)

        let waiter = Task { await queue.waitForTurn() }
        waiter.cancel()

        try await withTimeout { await waiter.value }

        let count = await queue.test_waiterCount()
        XCTAssertEqual(count, 0)

        await holder.value
    }

    /// test_9: a cancelled waiter does not break the slot handoff to the
    /// next waiter
    func test_9_cancelledWaiter_doesNotBreakQueue() async throws {
        // Holder claims the slot.
        let holder = Task {
            await queue.waitForTurn()
            try? await Task.sleep(nanoseconds: 500_000_000)
            await queue.finishPresentation()
        }
        await waitShort(0.05)

        // First waiter gets cancelled before its turn arrives.
        let cancelled = Task { await queue.waitForTurn() }
        await waitShort(0.05)
        cancelled.cancel()

        // Second waiter queues behind the cancelled one.
        let served = PresFlag()
        let next = Task {
            await queue.waitForTurn()
            served.mark()
            await queue.finishPresentation()
        }
        await waitShort(0.05)

        // The cancelled waiter's wait ends immediately.
        try await withTimeout { await cancelled.value }

        // The holder releases; the slot must reach the surviving waiter.
        await holder.value
        try await withTimeout { await next.value }

        XCTAssertTrue(served.isSet, "Slot must reach the waiter that follows a cancelled one")
    }
}

/// Timeout error used by the local wait helper.
private struct PresTimeoutError: Error {}

/// Sendable flag for presentation state.
private final class PresFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _set = false
    func mark() {
        lock.lock()
        _set = true
        lock.unlock()
    }
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _set
    }
}

/// Sendable ordered int collector.
private final class PresOrderedInts: @unchecked Sendable {
    private let lock = NSLock()
    private var _storage: [Int] = []
    func add(_ v: Int) {
        lock.lock()
        _storage.append(v)
        lock.unlock()
    }
    var allValues: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return _storage
    }
}

/// Sendable counter.
private final class PresCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    func inc() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}
