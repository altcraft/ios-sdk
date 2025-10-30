//
//  MobileEventCommandQueueTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * MobileEventCommandQueueTests
 *
 * Positive scenarios:
 *  - test_1: Submit multiple jobs without epoch → executes in strict FIFO submission order.
 *  - test_2: Reset without epoch and dropCurrent=false → clears queued jobs but lets current job finish.
 *  - test_3: Reset with epoch and dropCurrent=true → cancels pipeline and runs new generation jobs.
 *  - test_4: Multiple resets with epoch → only jobs submitted after last reset continue execution.
 *  - test_5: Submit while job is running → enqueues and executes new job after current completion.
 *
 * Notes:
 *  - Jobs are async with small delays to simulate real work.
 *  - With usesEpoch=true, reset(dropCurrent:true) prevents old generation continuation but doesn't stop current job side effects.
 *  - Tests focus on observable behavior: FIFO order and pipeline cancellation semantics.
 */
final class MobileEventCommandQueueTests: XCTestCase {
    private final class SafeLog {
        private let q = DispatchQueue(label: "MobileEventCommandQueueTests.SafeLog")
        private var arr: [String] = []
        func append(_ s: String) { q.async { self.arr.append(s) } }
        func snapshot() -> [String] { q.sync { arr } }
    }

    private func makeJob(
        _ mark: String,
        log: SafeLog,
        fulfill exp: XCTestExpectation? = nil,
        delay: TimeInterval = 0.03
    ) -> MobileEventCommandQueue.Job {
        return { done in
            log.append(mark)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                exp?.fulfill()
                done()
            }
        }
    }

    // MARK: - 1. FIFO

    /// Submit three jobs -> they must run strictly in FIFO order.
    func test_1_fifo_executes_jobs_in_submission_order() {
        let q = MobileEventCommandQueue(label: "test.queue.fifo", usesEpoch: false)
        let log = SafeLog()

        let exp = expectation(description: "all three jobs complete")
        exp.expectedFulfillmentCount = 3

        q.submit(makeJob("1", log: log, fulfill: exp))
        q.submit(makeJob("2", log: log, fulfill: exp))
        q.submit(makeJob("3", log: log, fulfill: exp))

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(log.snapshot(), ["1", "2", "3"])
    }

    // MARK: - 2. reset without epoch

    /// For usesEpoch = false, reset(dropCurrent: false) clears queued jobs but lets the current one finish.
    func test_2_reset_without_epoch_clears_future_jobs_but_keeps_current() {
        let q = MobileEventCommandQueue(label: "test.queue.noepoch", usesEpoch: false)
        let log = SafeLog()

        let done1 = expectation(description: "job1 completes")
        let maybe2 = expectation(description: "job2 would complete if not cleared")
        let maybe3 = expectation(description: "job3 would complete if not cleared")

        // job1 is running; job2 and job3 will be cleared by reset(dropCurrent: false)
        q.submit(makeJob("1", log: log, fulfill: done1, delay: 0.06))
        q.submit(makeJob("2", log: log, fulfill: maybe2))
        q.submit(makeJob("3", log: log, fulfill: maybe3))

        // Give the queue a moment to start job1, then reset without dropping current
        usleep(20_000) // 20 ms
        q.reset(dropCurrent: false)

        wait(for: [done1], timeout: 1.0)

        // job2/job3 must NOT have fulfilled; wait briefly and check no extra marks
        let short = XCTWaiter.wait(for: [maybe2, maybe3], timeout: 0.15)
        XCTAssertEqual(short, .timedOut, "queued jobs should be cleared and never fulfill")

        XCTAssertEqual(log.snapshot(), ["1"], "only the current job should run")
    }

    // MARK: - 3. reset with epoch (dropCurrent = true)

    /// For usesEpoch = true, reset(dropCurrent: true) cancels the pipeline (prevents old-gen continuation),
    /// and newly submitted jobs run in the new generation.
    func test_3_reset_with_epoch_drops_pipeline_and_runs_new_generation() {
        let q = MobileEventCommandQueue(label: "test.queue.epoch", usesEpoch: true)
        let log = SafeLog()

        let doneNew1 = expectation(description: "new-gen job A completes")
        let doneNew2 = expectation(description: "new-gen job B completes")

        // Submit job in old generation and a queued follower
        // Note: side effects of the currently running job may still happen.
        q.submit(makeJob("old:1", log: log, delay: 0.06))
        q.submit(makeJob("old:2", log: log)) // Should be dropped by reset

        usleep(20_000) // allow old:1 to start
        q.reset(dropCurrent: true)
        q.submit(makeJob("new:A", log: log, fulfill: doneNew1))
        q.submit(makeJob("new:B", log: log, fulfill: doneNew2))

        wait(for: [doneNew1, doneNew2], timeout: 1.0)

        let snapshot = log.snapshot()

        XCTAssertFalse(snapshot.contains("old:2"))
        
        if let a = snapshot.firstIndex(of: "new:A"), let b = snapshot.firstIndex(of: "new:B") {
            XCTAssertLessThan(a, b)
        } else {
            XCTFail("new generation jobs must run")
        }
    }

    // MARK: - 4. multiple resets with epoch

    /// Multiple resets bump generation repeatedly; only jobs submitted after the last reset shall continue.
    func test_4_multiple_resets_with_epoch_only_latest_generation_continues() {
        let q = MobileEventCommandQueue(label: "test.queue.multi.epoch", usesEpoch: true)
        let log = SafeLog()

        q.submit(makeJob("old:1", log: log, delay: 0.05))
        q.submit(makeJob("old:2", log: log))

        usleep(15_000)
        q.reset(dropCurrent: true)
        usleep(10_000)
        q.reset(dropCurrent: true)

        let doneX = expectation(description: "latest-gen X completes")
        let doneY = expectation(description: "latest-gen Y completes")

        // Latest generation jobs
        q.submit(makeJob("latest:X", log: log, fulfill: doneX))
        q.submit(makeJob("latest:Y", log: log, fulfill: doneY))

        wait(for: [doneX, doneY], timeout: 1.0)

        let s = log.snapshot()

        XCTAssertFalse(s.contains("old:2"))
        XCTAssertTrue(s.contains("latest:X"))
        XCTAssertTrue(s.contains("latest:Y"))
        if let x = s.firstIndex(of: "latest:X"), let y = s.firstIndex(of: "latest:Y") {
            XCTAssertLessThan(x, y)
        }
    }

    // MARK: - 5. submit while running

    /// Submitting while a job is running must enqueue and execute the new job after the current one.
    func test_5_submit_while_running_enqueues_and_runs_after() {
        let q = MobileEventCommandQueue(label: "test.queue.enqueue.while.running", usesEpoch: false)
        let log = SafeLog()
        
        let done1 = expectation(description: "first completes")
        let done2 = expectation(description: "second completes")

        q.submit(makeJob("first", log: log, fulfill: done1, delay: 0.05))
        usleep(15_000)
        q.submit(makeJob("second", log: log, fulfill: done2))

        wait(for: [done1, done2], timeout: 1.0)
        XCTAssertEqual(log.snapshot(), ["first", "second"])
    }
}
