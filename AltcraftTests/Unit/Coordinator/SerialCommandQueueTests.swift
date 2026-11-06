//
//  SerialCommandQueueTests.swift
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
 * SerialCommandQueueTests
 *
 * Positive scenarios:
 *  - test_1: submit executes jobs one at a time in FIFO order.
 *  - test_2: jobs submitted in one burst after reset keep strict FIFO order
 *    among themselves (guards the reset race where a pending submission
 *    block could start unchained and interleave with other jobs).
 *  - test_3: reset cancels the in-flight tail job so its work is dropped.
 *
 */
final class SerialCommandQueueTests: IsolatedTestCase {

    /// test_1: submit executes jobs one at a time in FIFO order
    func test_1_submit_executesJobsInFifoOrder() async {
        let queue = SerialCommandQueue(label: "test.scq.fifo")
        let log = OrderLog()

        for index in 0..<10 {
            queue.submit { await log.append(index) }
        }

        let sentinel = Flag()
        queue.submit { await sentinel.setTrue() }

        var finished = false
        for _ in 0..<100 {
            if await sentinel.value() {
                finished = true
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertTrue(finished, "sentinel job must complete")

        let order = await log.values()
        XCTAssertEqual(order, Array(0..<10))
    }

    /// test_2: jobs submitted in one burst after reset keep strict FIFO order.
    ///
    /// Stress regression for the reset race: the submission block used to run
    /// asynchronously, so a `reset()` landing before it left the job unchained
    /// and free to interleave with the rest of the burst. Within each burst
    /// the ordering below must always hold.
    func test_2_submitAfterReset_keepsFifoOrderWithinBurst() async {
        let queue = SerialCommandQueue(label: "test.scq.reset")
        let log = OrderLog()

        for round in 0..<25 {
            queue.reset()

            for index in 0..<3 {
                queue.submit {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                    await log.append(round * 100 + index)
                }
            }
        }

        let sentinel = Flag()
        queue.submit { await sentinel.setTrue() }

        var finished = false
        for _ in 0..<200 {
            if await sentinel.value() {
                finished = true
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertTrue(finished, "sentinel job must complete")

        let order = await log.values()

        // Every burst runs as a strictly ordered chain. reset() cancels the
        // previous burst's tail, which may drop that job entirely, so only
        // the first two jobs of each burst are guaranteed to run; the third
        // must simply come after the second whenever it runs.
        for round in 0..<25 {
            let first = order.firstIndex(of: round * 100)
            let second = order.firstIndex(of: round * 100 + 1)
            let third = order.firstIndex(of: round * 100 + 2)

            XCTAssertNotNil(first, "job \(round * 100) must run")
            XCTAssertNotNil(second, "job \(round * 100 + 1) must run")

            if let first, let second {
                XCTAssertLessThan(first, second)
            }
            if let second, let third {
                XCTAssertLessThan(second, third)
            }
        }
    }

    /// test_3: reset cancels the in-flight tail job so its work is dropped.
    func test_3_reset_dropsInFlightJob() async {
        let queue = SerialCommandQueue(label: "test.scq.drop")
        let log = OrderLog()

        queue.submit {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            await log.append(1)
        }

        queue.reset()

        queue.submit { await log.append(2) }

        var finished = false
        for _ in 0..<100 {
            let values = await log.values()
            if !values.isEmpty {
                finished = true
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertTrue(finished, "post-reset job must run")

        let order = await log.values()
        XCTAssertEqual(
            order,
            [2],
            "cancelled in-flight job must be dropped, post-reset job must run"
        )
    }
    /// test_4: submit returns a handle completing only after the job finishes.
    func test_4_submit_returnsHandleCompletingAfterJob() async {
        let queue = SerialCommandQueue(label: "test.scq.handle")
        let flag = Flag()

        let handle = queue.submit {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await flag.setTrue()
        }

        let completedBefore = await flag.value()
        XCTAssertFalse(
            completedBefore,
            "handle must not complete before the job body"
        )

        await handle.value

        let completedAfter = await flag.value()
        XCTAssertTrue(
            completedAfter,
            "handle must complete only after the job body"
        )
    }

    /// test_5: submit on a suspended queue returns a completed handle and
    /// normal work resumes after `resume()`.
    func test_5_suspendedQueue_submitReturnsCompletedHandle() async {
        let queue = SerialCommandQueue(label: "test.scq.suspend")
        let log = OrderLog()

        queue.suspend()

        let handle = queue.submit { await log.append(1) }

        await handle.value

        let dropped = await log.values()
        XCTAssertTrue(
            dropped.isEmpty,
            "a job submitted while suspended must be dropped"
        )

        queue.resume()

        queue.submit { await log.append(2) }

        var finished = false
        for _ in 0..<100 {
            let values = await log.values()
            if values.contains(2) {
                finished = true
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertTrue(finished, "post-resume job must run")
    }
}

private actor OrderLog {
    private var storage: [Int] = []

    func append(_ value: Int) {
        storage.append(value)
    }

    func values() -> [Int] {
        storage
    }
}

private actor Flag {
    private var storage = false

    func setTrue() {
        storage = true
    }

    func value() -> Bool {
        storage
    }
}
