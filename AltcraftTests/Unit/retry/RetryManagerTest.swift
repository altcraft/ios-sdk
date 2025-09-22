//
//  RetryManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * RetryManagerTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_store_replacesExisting_cancelsOld_runsNew
 *  - test_2_cancelAll_cancelsScheduledWork_onAllQueues
 *  - test_3_store_withDifferentKeys_runsIndependently
 *  - test_4_concurrentStore_sameKey_isThreadSafe_lastWins
 *
 * Notes:
 *  - We always schedule the exact DispatchWorkItem saved via store(...),
 *    so that RetryManager’s cancellation actually prevents its execution.
 *  - Small delays and moderate timeouts reduce flakiness while keeping tests fast.
 */
final class RetryManagerTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        RetryManager.shared.cancelAll()
    }

    // MARK: - 1. Replacement by key

    /// New store() under the same key cancels the old work; only the new one runs.
    func test_1_store_replacesExisting_cancelsOld_runsNew() {
        let mgr = RetryManager.shared

        let oldRan = AtomicInt()
        let newRan = AtomicInt()
        let exp = expectation(description: "new work runs, old is cancelled")

        let oldWork = DispatchWorkItem {
            oldRan.increment()
        }
        mgr.store(key: "K", work: oldWork)
        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.06, execute: oldWork)

        let newWork = DispatchWorkItem {
            newRan.increment()
            exp.fulfill()
        }
        // Storing the new work should cancel the old one
        mgr.store(key: "K", work: newWork)
        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.06, execute: newWork)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(oldRan.value, 0, "Old work should be cancelled and never run")
        XCTAssertEqual(newRan.value, 1, "New work should run exactly once")
    }

    // MARK: - 2. Global cancellation

    /// cancelAll() cancels all scheduled work across all queues.
    func test_2_cancelAll_cancelsScheduledWork_onAllQueues() {
        let mgr = RetryManager.shared

        let subRan = AtomicInt()
        let updRan = AtomicInt()
        let evtRan = AtomicInt()

        let w1 = DispatchWorkItem { subRan.increment() }
        let w2 = DispatchWorkItem { updRan.increment() }
        let w3 = DispatchWorkItem { evtRan.increment() }

        mgr.store(key: "S", work: w1)
        mgr.store(key: "U", work: w2)
        mgr.store(key: "E", work: w3)

        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.08, execute: w1)
        mgr.tokenUpdateQueue.asyncAfter(deadline: .now() + 0.08, execute: w2)
        mgr.pushEventQueue.asyncAfter(deadline: .now() + 0.08, execute: w3)

        // Cancel everything immediately
        mgr.cancelAll()

        let exp = expectation(description: "none runs after cancelAll")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
            XCTAssertEqual(subRan.value, 0)
            XCTAssertEqual(updRan.value, 0)
            XCTAssertEqual(evtRan.value, 0)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    // MARK: - 3. Different keys are independent

    /// Different keys track separate work items; both should run.
    func test_3_store_withDifferentKeys_runsIndependently() {
        let mgr = RetryManager.shared

        let aRan = AtomicInt()
        let bRan = AtomicInt()
        let exp = expectation(description: "both run")
        exp.expectedFulfillmentCount = 2

        let wa = DispatchWorkItem { aRan.increment(); exp.fulfill() }
        let wb = DispatchWorkItem { bRan.increment(); exp.fulfill() }

        mgr.store(key: "A", work: wa)
        mgr.store(key: "B", work: wb)

        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.04, execute: wa)
        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.05, execute: wb)

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(aRan.value, 1)
        XCTAssertEqual(bRan.value, 1)
    }

    // MARK: - 4. Concurrent store for the same key

    /// Concurrent store() calls for the same key: only the last scheduled work executes.
    func test_4_concurrentStore_sameKey_isThreadSafe_lastWins() {
        let mgr = RetryManager.shared

        let total = 10
        let counters = (0..<total).map { _ in AtomicInt() }
        let works: [DispatchWorkItem] = counters.enumerated().map { (_, counter) in
            DispatchWorkItem { counter.increment() }
        }

        // Concurrently call store for the same key and schedule each work.
        DispatchQueue.concurrentPerform(iterations: total) { i in
            mgr.store(key: "ONE", work: works[i])
            mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.07, execute: works[i])
        }

        let exp = expectation(description: "only last runs")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            let ranCount = counters.map { $0.value }.reduce(0, +)
            XCTAssertEqual(ranCount, 1, "Only the last stored work should run")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

// MARK: - Tiny atomic int helper to avoid data races in tests

private final class AtomicInt {
    private var _v: Int32 = 0
    func increment() { OSAtomicIncrement32(&_v) }
    var value: Int { Int(OSAtomicAdd32(0, &_v)) }
}

