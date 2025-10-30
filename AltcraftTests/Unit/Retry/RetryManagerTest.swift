//
//  RetryManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * RetryManagerTests
 *
 * Coverage:
 *  - test_1_store_replaces_existing_task_and_cancels_old
 *  - test_2_cancelAll_cancels_pending_tasks_across_all_queues
 *  - test_3_queues_execute_scheduled_tasks_independently
 *  - test_4_store_is_thread_safe_last_task_runs
 */
final class RetryManagerTests: XCTestCase {

    override func tearDown() {
        RetryManager.shared.cancelAll()
        super.tearDown()
    }

    /// Ensures store(key:) cancels previous task with the same key and only the latest runs.
    func test_1_store_replaces_existing_task_and_cancels_old() {
        let mgr = RetryManager.shared

        let firedOld = XCTestExpectation(description: "old should NOT fire")
        firedOld.isInverted = true

        let firedNew = expectation(description: "new should fire")

        let oldWork = DispatchWorkItem {
            firedOld.fulfill()
        }
        let newWork = DispatchWorkItem {
            firedNew.fulfill()
        }

        mgr.store(key: "K", work: oldWork)
        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.15, execute: oldWork)

        mgr.store(key: "K", work: newWork)
        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.10, execute: newWork)

        wait(for: [firedNew, firedOld], timeout: 1.0)
    }

    /// Verifies cancelAll() cancels all pending tasks on all queues.
    func test_2_cancelAll_cancels_pending_tasks_across_all_queues() {
        let mgr = RetryManager.shared

        let subDidNotFire = XCTestExpectation(description: "sub should be cancelled")
        let tokDidNotFire = XCTestExpectation(description: "token should be cancelled")
        let pushDidNotFire = XCTestExpectation(description: "push should be cancelled")
        let mobDidNotFire  = XCTestExpectation(description: "mobile should be cancelled")

        subDidNotFire.isInverted = true
        tokDidNotFire.isInverted = true
        pushDidNotFire.isInverted = true
        mobDidNotFire.isInverted  = true

        let sub = DispatchWorkItem { subDidNotFire.fulfill() }
        let tok = DispatchWorkItem { tokDidNotFire.fulfill() }
        let push = DispatchWorkItem { pushDidNotFire.fulfill() }
        let mob  = DispatchWorkItem { mobDidNotFire.fulfill() }

        mgr.store(key: "sub", work: sub)
        mgr.store(key: "tok", work: tok)
        mgr.store(key: "push", work: push)
        mgr.store(key: "mob", work: mob)

        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.2, execute: sub)
        mgr.tokenUpdateQueue.asyncAfter(deadline: .now() + 0.2, execute: tok)
        mgr.pushEventQueue.asyncAfter(deadline: .now() + 0.2, execute: push)
        mgr.mobileEventQueue.asyncAfter(deadline: .now() + 0.2, execute: mob)

        mgr.cancelAll()

        wait(for: [subDidNotFire, tokDidNotFire, pushDidNotFire, mobDidNotFire], timeout: 0.5)
    }

    /// Confirms different queues execute their scheduled tasks independently.
    func test_3_queues_execute_scheduled_tasks_independently() {
        let mgr = RetryManager.shared

        let exp = expectation(description: "all queues fired")
        exp.expectedFulfillmentCount = 4

        let sub = DispatchWorkItem { exp.fulfill() }
        let tok = DispatchWorkItem { exp.fulfill() }
        let push = DispatchWorkItem { exp.fulfill() }
        let mob  = DispatchWorkItem { exp.fulfill() }

        mgr.store(key: "subQ", work: sub)
        mgr.store(key: "tokQ", work: tok)
        mgr.store(key: "pushQ", work: push)
        mgr.store(key: "mobQ", work: mob)

        mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.05, execute: sub)
        mgr.tokenUpdateQueue.asyncAfter(deadline: .now() + 0.06, execute: tok)
        mgr.pushEventQueue.asyncAfter(deadline: .now() + 0.07, execute: push)
        mgr.mobileEventQueue.asyncAfter(deadline: .now() + 0.08, execute: mob)

        // Было 1.0 — слишком агрессивно на загруженных машинах
        wait(for: [exp], timeout: 3.0)
    }


    /// Stress: concurrent store(key:) calls are safe; the last stored task runs.
    func test_4_store_is_thread_safe_last_task_runs() {
        let mgr = RetryManager.shared

        let didRun = expectation(description: "last work ran")

        let iterations = 50
        let key = "race-key"
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let work = DispatchWorkItem { /* no-op */ }
                mgr.store(key: key, work: work)
                mgr.subscribeQueue.asyncAfter(deadline: .now() + 0.1, execute: work)
                group.leave()
            }
        }

        XCTAssertEqual(group.wait(timeout: .now() + 1.5), .success)

        let final = DispatchWorkItem { didRun.fulfill() }
        mgr.store(key: key, work: final)
        mgr.subscribeQueue.async(execute: final)

        wait(for: [didRun], timeout: 3.0)
    }
}
