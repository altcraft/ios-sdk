//
//  UpdateCoordinatorTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * UpdateCoordinatorTests
 *
 * Positive scenarios:
 *  - test_1: run with concurrent callers → coalesces into a single operation call and returns same result to all.
 *  - test_2: run → allows new operation after previous finish.
 *  - test_3: run with callback while running → appends completions and all are called on finish.
 *  - test_4: run without callback → still performs operation and returns result.
 *  - test_5: run reentrant from callback → starts a new operation after finish and does not lose callbacks.
 *  - test_6: run with many concurrent callers → still runs exactly once and delivers same result to all.
 *
 */
final class UpdateCoordinatorTests: IsolatedTestCase {

    private func makeCoordinator<T: Sendable>() -> UpdateCoordinator<T> {
        UpdateCoordinator<T>()
    }

    actor IntRecorder {
        private var values: [Int] = []

        func append(_ value: Int) {
            values.append(value)
        }

        func snapshot() -> [Int] {
            values
        }

        func count() -> Int {
            values.count
        }
    }

    actor StringRecorder {
        private var values: [String] = []

        func append(_ value: String) {
            values.append(value)
        }

        func snapshot() -> [String] {
            values
        }
    }

    actor Counter {
        private var value = 0

        func increment() -> Int {
            value += 1
            return value
        }

        func get() -> Int {
            value
        }
    }

    /// test_1: run with concurrent callers coalesces into a single operation call and returns same result to all
    func test_1_run_withConcurrentCallers_coalescesIntoSingleOperation_andReturnsSameResultToAll() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>
        let recorder = IntRecorder()
        let counter = Counter()

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await coordinator.run {
                        let call = await counter.increment()
                        XCTAssertEqual(call, 1)
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        return 777
                    }
                }
            }

            for await value in group {
                await recorder.append(value)
            }
        }

        let calls = await counter.get()
        let received = await recorder.snapshot()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(received.count, 20)
        XCTAssertTrue(received.allSatisfy { $0 == 777 })
    }

    /// test_2: run allows new operation after previous finish
    func test_2_run_allowsNewOperationAfterPreviousFinish() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<String>
        let recorder = StringRecorder()
        let counter = Counter()

        let first = await coordinator.run {
            let call = await counter.increment()
            XCTAssertEqual(call, 1)
            try? await Task.sleep(nanoseconds: 30_000_000)
            return "A"
        }
        await recorder.append(first)

        let second = await coordinator.run {
            let call = await counter.increment()
            XCTAssertEqual(call, 2)
            try? await Task.sleep(nanoseconds: 30_000_000)
            return "B"
        }
        await recorder.append(second)

        let calls = await counter.get()
        let values = await recorder.snapshot()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(values, ["A", "B"])
    }

    /// test_3: run with callback while running appends completions and all are called on finish
    func test_3_run_withCallbackWhileRunning_appendsCompletions_andAllAreCalledOnFinish() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>
        let counter = Counter()
        let recorder = IntRecorder()

        let done = expectation(description: "all callback completions called")
        done.expectedFulfillmentCount = 3

        await coordinator.run(operation: {
            let call = await counter.increment()
            XCTAssertEqual(call, 1)
            try? await Task.sleep(nanoseconds: 80_000_000)
            return 42
        }, completion: { value in
            Task {
                await recorder.append(value)
                done.fulfill()
            }
        })

        await coordinator.run(operation: {
            XCTFail("operation must not be called while already running")
            return 0
        }, completion: { value in
            Task {
                await recorder.append(value)
                done.fulfill()
            }
        })

        await coordinator.run(operation: {
            XCTFail("operation must not be called while already running")
            return 0
        }, completion: { value in
            Task {
                await recorder.append(value)
                done.fulfill()
            }
        })

        await fulfillment(of: [done], timeout: 2.0)

        let calls = await counter.get()
        let results = await recorder.snapshot()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0 == 42 })
    }

    /// test_4: run without callback still performs operation and returns result
    func test_4_run_withoutCallback_stillPerformsOperation_andReturnsResult() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>
        let counter = Counter()

        let value = await coordinator.run {
            let call = await counter.increment()
            XCTAssertEqual(call, 1)
            try? await Task.sleep(nanoseconds: 30_000_000)
            return 123
        }

        let calls = await counter.get()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(value, 123)
    }

    /// test_5: run reentrant from callback starts a new operation after finish and does not lose callbacks
    func test_5_run_reentrantFromCallback_startsNewOperationAfterFinish_andDoesNotLoseCallbacks() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>
        let counter = Counter()
        let recorder = IntRecorder()

        let done = expectation(description: "both callback completions called")
        done.expectedFulfillmentCount = 2

        await coordinator.run(operation: {
            let call = await counter.increment()
            XCTAssertEqual(call, 1)
            try? await Task.sleep(nanoseconds: 30_000_000)
            return 1
        }, completion: { value in
            Task {
                await recorder.append(value)
                done.fulfill()
            }

            Task {
                await coordinator.run(operation: {
                    let call = await counter.increment()
                    XCTAssertEqual(call, 2)
                    try? await Task.sleep(nanoseconds: 30_000_000)
                    return 2
                }, completion: { secondValue in
                    Task {
                        await recorder.append(secondValue)
                        done.fulfill()
                    }
                })
            }
        })

        await fulfillment(of: [done], timeout: 2.0)

        let calls = await counter.get()
        let values = await recorder.snapshot()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(values, [1, 2])
    }

    /// test_6: run with many concurrent callers still runs exactly once and delivers same result to all
    func test_6_run_withManyConcurrentCallers_stillRunsExactlyOnce_andDeliversSameResultToAll() async {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>
        let counter = Counter()
        let recorder = IntRecorder()

        await withTaskGroup(of: Int.self) { group in
            for _ in 0..<200 {
                group.addTask {
                    await coordinator.run {
                        let call = await counter.increment()
                        XCTAssertEqual(call, 1)
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        return 999
                    }
                }
            }

            for await value in group {
                await recorder.append(value)
            }
        }

        let calls = await counter.get()
        let values = await recorder.snapshot()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(values.count, 200)
        XCTAssertEqual(values.min(), 999)
        XCTAssertEqual(values.max(), 999)
    }
}
