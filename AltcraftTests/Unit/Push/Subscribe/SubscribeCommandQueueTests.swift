//
//  SubscribeCommandQueueTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * SubscribeCommandQueueTests
 *
 * Positive scenarios:
 *  - test_1: FIFO → executes jobs in submit order when each calls done.
 *  - test_2: nextJob → starts only after done is called.
 *  - test_3: reset without epoch dropCurrent false → drops pending but lets current finish.
 *  - test_4: reset with epoch dropCurrent true → stops continuation and drops pending.
 *  - test_5: reset with epoch dropCurrent false → drops pending but continues after current if any.
 *  - test_6: concurrent submissions → are serialized with no overlap.
 */
final class SubscribeCommandQueueTests: XCTestCase {

    private func asyncAfter(_ seconds: TimeInterval, _ block: @escaping () -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: block)
    }

    /// test_1: FIFO executes jobs in submit order when each calls done
    func test_1_FIFO_executesJobsInSubmitOrder_whenEachCallsDone() {
        let q = SubscribeCommandQueue(label: "test.queue.fifo", usesEpoch: false)

        var order: [Int] = []
        let lock = NSLock()
        let exp = expectation(description: "fifo")
        exp.expectedFulfillmentCount = 3

        for i in 1...3 {
            q.submit { done in
                lock.lock(); order.append(i); lock.unlock()
                exp.fulfill()
                done()
            }
        }

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(order, [1, 2, 3], "Jobs must run in FIFO order")
    }

    /// test_2: nextJob starts only after done is called
    func test_2_nextJob_startsOnlyAfter_done_isCalled() {
        let q = SubscribeCommandQueue(label: "test.queue.done.gating", usesEpoch: false)

        var started: [Int] = []
        let lock = NSLock()
        let exp = expectation(description: "two jobs")
        exp.expectedFulfillmentCount = 2

        q.submit { done in
            lock.lock(); started.append(1); lock.unlock()
            self.asyncAfter(0.15) {
                exp.fulfill()
                done()
            }
        }

        q.submit { done in
            lock.lock(); started.append(2); lock.unlock()
            exp.fulfill()
            done()
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(started, [1, 2], "Second job must not start before the first calls done()")
    }

    /// test_3: reset without epoch dropCurrent false drops pending but lets current finish
    func test_3_reset_withoutEpoch_dropCurrentFalse_dropsPending_but_letsCurrentFinish() {
        let q = SubscribeCommandQueue(label: "test.queue.reset.noepoch", usesEpoch: false)

        let started = NSMutableArray()
        let finished = NSMutableArray()
        let exp1 = expectation(description: "first runs and finishes")

        q.submit { done in
            started.add(1)
            q.reset(dropCurrent: false)
            self.asyncAfter(0.05) {
                finished.add(1)
                exp1.fulfill()
                done()
            }
        }

        q.submit { done in started.add(2); finished.add(2); done() }
        q.submit { done in started.add(3); finished.add(3); done() }

        wait(for: [exp1], timeout: 1.0)

        XCTAssertEqual(started as? [Int], [1], "Only the current job should start")
        XCTAssertEqual(finished as? [Int], [1], "Only the current job should finish")
    }

    /// test_4: reset with epoch dropCurrent true stops continuation and drops pending
    func test_4_reset_withEpoch_dropCurrentTrue_stopsContinuation_and_dropsPending() {
        let q = SubscribeCommandQueue(label: "test.queue.reset.epoch.drop", usesEpoch: true)

        let started = NSMutableArray()
        let finished = NSMutableArray()
        let exp1 = expectation(description: "first finishes; chain stops")

        q.submit { done in
            started.add(1)
            q.reset(dropCurrent: true)
            self.asyncAfter(0.05) {
                finished.add(1)
                exp1.fulfill()
                done()
            }
        }

        q.submit { done in started.add(2); finished.add(2); done() }
        q.submit { done in started.add(3); finished.add(3); done() }

        wait(for: [exp1], timeout: 1.0)

        XCTAssertEqual(started as? [Int], [1], "Only the current job should start")
        XCTAssertEqual(finished as? [Int], [1], "Only the current job should finish")

        let exp2 = expectation(description: "new generation runs")
        q.submit { done in
            started.add(4); finished.add(4)
            exp2.fulfill(); done()
        }
        wait(for: [exp2], timeout: 1.0)

        XCTAssertEqual(started as? [Int], [1, 4])
        XCTAssertEqual(finished as? [Int], [1, 4])
    }

    /// test_5: reset with epoch dropCurrent false drops pending but continues after current if any
    func test_5_reset_withEpoch_dropCurrentFalse_dropsPending_but_continuesAfterCurrentIfAny() {
        let q = SubscribeCommandQueue(label: "test.queue.reset.epoch.keep", usesEpoch: true)

        let started = NSMutableArray()
        let finished = NSMutableArray()
        let exp1 = expectation(description: "first finishes")

        q.submit { done in
            started.add(1)
            q.reset(dropCurrent: false)
            self.asyncAfter(0.05) {
                finished.add(1)
                exp1.fulfill()
                done()
            }
        }

        q.submit { done in started.add(2); finished.add(2); done() }
        q.submit { done in started.add(3); finished.add(3); done() }

        wait(for: [exp1], timeout: 1.0)

        XCTAssertEqual(started as? [Int], [1], "Pending jobs should be dropped")
        XCTAssertEqual(finished as? [Int], [1], "Pending jobs should be dropped")

        let exp2 = expectation(description: "new submit after keep-current")
        q.submit { done in
            started.add(4); finished.add(4)
            exp2.fulfill(); done()
        }
        wait(for: [exp2], timeout: 1.0)

        XCTAssertEqual(started as? [Int], [1, 4])
        XCTAssertEqual(finished as? [Int], [1, 4])
    }

    /// test_6: concurrent submissions are serialized with no overlap
    func test_6_concurrentSubmissions_areSerialized_noOverlap() {
        let q = SubscribeCommandQueue(label: "test.queue.serialized", usesEpoch: false)

        let exp = expectation(description: "five serialized jobs")
        exp.expectedFulfillmentCount = 5

        let guardLock = NSLock()
        var active = 0
        var overlaps = 0

        for _ in 0..<5 {
            DispatchQueue.global().async {
                q.submit { done in
                    guardLock.lock()
                    if active != 0 { overlaps += 1 }
                    active += 1
                    guardLock.unlock()

                    Thread.sleep(forTimeInterval: 0.03)

                    guardLock.lock()
                    active -= 1
                    guardLock.unlock()

                    exp.fulfill()
                    done()
                }
            }
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(overlaps, 0, "Jobs must never overlap; queue must serialize execution")
    }
}
