//
//  ProfileUpdateCommandQueueTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * ProfileUpdateCommandQueueTests
 *
 * Positive scenarios:
 *  - test_1: FIFO → executes jobs in submit order.
 *  - test_2: nextJob → starts only after previous job finishes.
 *  - test_3: reset without epoch dropCurrent false → keeps current and pending jobs.
 *  - test_4: reset with epoch dropCurrent true → drops pending jobs from old generation.
 *  - test_5: reset with epoch dropCurrent false and epoch queue → keeps current generation jobs.
 *  - test_6: concurrent submissions → are serialized with no overlap.
 */
final class ProfileUpdateCommandQueueTests: IsolatedTestCase {

    actor IntRecorder {
        private var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }

        func snapshot() -> [Int] {
            values
        }
    }

    actor OverlapTracker {
        private var active = 0
        private var overlaps = 0

        func begin() {
            if active != 0 {
                overlaps += 1
            }
            active += 1
        }

        func end() {
            active -= 1
        }

        func overlapCount() -> Int {
            overlaps
        }
    }

    /// test_1: FIFO executes jobs in submit order
    func test_1_FIFO_executesJobsInSubmitOrder() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.fifo",
            usesEpoch: false
        )

        let recorder = IntRecorder()
        let exp = expectation(description: "fifo")
        exp.expectedFulfillmentCount = 3

        for i in 1...3 {
            queue.submit {
                await recorder.append(i)
                exp.fulfill()
            }
        }

        await fulfillment(of: [exp], timeout: 1.0)
        let order = await recorder.snapshot()
        XCTAssertEqual(order, [1, 2, 3], "Jobs must run in FIFO order")
    }

    /// test_2: nextJob starts only after previous job finishes
    func test_2_nextJob_startsOnlyAfter_previousJob_finishes() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.next.gating",
            usesEpoch: false
        )

        let recorder = IntRecorder()
        let exp = expectation(description: "two jobs")
        exp.expectedFulfillmentCount = 2

        queue.submit {
            await recorder.append(1)
            try? await Task.sleep(nanoseconds: 150_000_000)
            exp.fulfill()
        }

        queue.submit {
            await recorder.append(2)
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 2.0)
        let started = await recorder.snapshot()
        XCTAssertEqual(started, [1, 2], "Second job must not start before the first finishes")
    }

    /// test_3: reset without epoch dropCurrent false keeps current and pending jobs
    func test_3_reset_withoutEpoch_dropCurrentFalse_keepsCurrentAndPending() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.reset.noepoch",
            usesEpoch: false
        )

        let started = IntRecorder()
        let finished = IntRecorder()

        let exp = expectation(description: "all jobs finished")
        exp.expectedFulfillmentCount = 3

        queue.submit {
            await started.append(1)
            queue.reset(dropCurrent: false)

            try? await Task.sleep(nanoseconds: 50_000_000)

            await finished.append(1)
            exp.fulfill()
        }

        queue.submit {
            await started.append(2)
            await finished.append(2)
            exp.fulfill()
        }

        queue.submit {
            await started.append(3)
            await finished.append(3)
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)

        let startedSnapshot = await started.snapshot()
        let finishedSnapshot = await finished.snapshot()

        XCTAssertEqual(startedSnapshot, [1, 2, 3])
        XCTAssertEqual(finishedSnapshot, [1, 2, 3])
    }

    /// test_4: reset with epoch dropCurrent true drops pending jobs from old generation
    func test_4_reset_withEpoch_dropCurrentTrue_dropsPendingOldGeneration() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.reset.epoch.drop",
            usesEpoch: true
        )

        let started = IntRecorder()
        let finished = IntRecorder()

        let exp1 = expectation(description: "first finishes")
        let exp2 = expectation(description: "new generation runs")

        queue.submit {
            await started.append(1)
            queue.reset(dropCurrent: true)

            try? await Task.sleep(nanoseconds: 50_000_000)

            await finished.append(1)
            exp1.fulfill()
        }

        queue.submit {
            await started.append(2)
            await finished.append(2)
        }

        queue.submit {
            await started.append(3)
            await finished.append(3)
        }

        await fulfillment(of: [exp1], timeout: 1.0)

        let startedAfterFirst = await started.snapshot()
        let finishedAfterFirst = await finished.snapshot()

        XCTAssertEqual(startedAfterFirst, [1], "Only current job should run from old generation")
        XCTAssertEqual(finishedAfterFirst, [1], "Only current job should finish from old generation")

        queue.submit {
            await started.append(4)
            await finished.append(4)
            exp2.fulfill()
        }

        await fulfillment(of: [exp2], timeout: 1.0)

        let startedFinal = await started.snapshot()
        let finishedFinal = await finished.snapshot()

        XCTAssertEqual(startedFinal, [1, 4])
        XCTAssertEqual(finishedFinal, [1, 4])
    }

    /// test_5: reset with epoch dropCurrent false keeps current generation jobs
    func test_5_reset_withEpoch_dropCurrentFalse_keepsCurrentGenerationJobs() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.reset.epoch.keep",
            usesEpoch: true
        )

        let started = IntRecorder()
        let finished = IntRecorder()

        let exp = expectation(description: "all current generation jobs finished")
        exp.expectedFulfillmentCount = 3

        queue.submit {
            await started.append(1)
            queue.reset(dropCurrent: false)

            try? await Task.sleep(nanoseconds: 50_000_000)

            await finished.append(1)
            exp.fulfill()
        }

        queue.submit {
            await started.append(2)
            await finished.append(2)
            exp.fulfill()
        }

        queue.submit {
            await started.append(3)
            await finished.append(3)
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)

        let startedSnapshot = await started.snapshot()
        let finishedSnapshot = await finished.snapshot()

        XCTAssertEqual(startedSnapshot, [1, 2, 3])
        XCTAssertEqual(finishedSnapshot, [1, 2, 3])
    }

    /// test_6: concurrent submissions are serialized with no overlap
    func test_6_concurrentSubmissions_areSerialized_noOverlap() async {
        let queue = ProfileUpdateCommandQueue(
            label: "test.queue.serialized",
            usesEpoch: false
        )

        let tracker = OverlapTracker()
        let exp = expectation(description: "five serialized jobs")
        exp.expectedFulfillmentCount = 5

        for _ in 0..<5 {
            DispatchQueue.global().async {
                queue.submit {
                    await tracker.begin()

                    try? await Task.sleep(nanoseconds: 30_000_000)

                    await tracker.end()
                    exp.fulfill()
                }
            }
        }

        await fulfillment(of: [exp], timeout: 2.0)
        let overlaps = await tracker.overlapCount()
        XCTAssertEqual(overlaps, 0, "Jobs must never overlap; queue must serialize execution")
    }
}
