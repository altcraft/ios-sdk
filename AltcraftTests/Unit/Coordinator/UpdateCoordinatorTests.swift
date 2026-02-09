//
//  UpdateCoordinatorTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * UpdateCoordinatorTests
 *
 * Positive scenarios:
 *  - test_1: run (concurrent) → coalesces into a single operation call and delivers same result to all completions.
 *  - test_2: run → allows new operation after finish (no coalescing across finished runs).
 *  - test_3: run (while running) → appends completions and all are called on finish.
 *  - test_4: run (without completion) → still performs operation and does not crash.
 *  - test_5: run (reentrant from completion) → starts a new operation after finish and does not lose callbacks.
 *  - test_6: run (many concurrent callers) → still runs exactly once and delivers to all.
 */
final class UpdateCoordinatorTests: XCTestCase {

    private func makeCoordinator<T>() -> UpdateCoordinator<T> {
        UpdateCoordinator<T>(label: "altcraft.tests.updatecoordinator.\(UUID().uuidString)")
    }

    /// test_1: run (concurrent) → coalesces into a single operation call and delivers same result to all completions
    func test_1_run_concurrent_coalescesIntoSingleOperation_andDeliversSameResultToAll() {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>

        let callers = 20
        let start = DispatchGroup()
        let done = expectation(description: "all completions called")
        done.expectedFulfillmentCount = callers

        let opCalledOnce = expectation(description: "operation called once")
        opCalledOnce.expectedFulfillmentCount = 1

        let lock = NSLock()
        var operationCallCount = 0
        var received: [Int] = []

        for _ in 0..<callers {
            start.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.run(operation: { finish in
                    lock.lock()
                    operationCallCount += 1
                    let isFirst = (operationCallCount == 1)
                    lock.unlock()

                    if isFirst { opCalledOnce.fulfill() }

                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                        finish(777)
                    }
                }, completion: { value in
                    lock.lock()
                    received.append(value)
                    lock.unlock()
                    done.fulfill()
                })
                start.leave()
            }
        }

        start.wait()

        wait(for: [opCalledOnce, done], timeout: 2.0)

        lock.lock()
        let count = operationCallCount
        let allSame = received.allSatisfy { $0 == 777 }
        let receivedCount = received.count
        lock.unlock()

        XCTAssertEqual(count, 1)
        XCTAssertEqual(receivedCount, callers)
        XCTAssertTrue(allSame)
    }

    /// test_2: run → allows new operation after finish (no coalescing across finished runs)
    func test_2_run_allowsNewOperationAfterFinish() {
        let coordinator = makeCoordinator() as UpdateCoordinator<String>

        let firstDone = expectation(description: "first completion")
        let secondDone = expectation(description: "second completion")

        let lock = NSLock()
        var opCalls = 0
        var values: [String] = []

        coordinator.run(operation: { finish in
            lock.lock(); opCalls += 1; lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) { finish("A") }
        }, completion: { v in
            lock.lock(); values.append(v); lock.unlock()
            firstDone.fulfill()
        })

        wait(for: [firstDone], timeout: 1.0)

        coordinator.run(operation: { finish in
            lock.lock(); opCalls += 1; lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) { finish("B") }
        }, completion: { v in
            lock.lock(); values.append(v); lock.unlock()
            secondDone.fulfill()
        })

        wait(for: [secondDone], timeout: 1.0)

        lock.lock()
        let calls = opCalls
        let captured = values
        lock.unlock()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(captured, ["A", "B"])
    }

    /// test_3: run (while running) → appends completions and all are called on finish
    func test_3_run_whileRunning_appendsCompletions_andAllAreCalledOnFinish() {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>

        let done = expectation(description: "all completions called")
        done.expectedFulfillmentCount = 3

        let opCalledOnce = expectation(description: "operation called once")
        opCalledOnce.expectedFulfillmentCount = 1

        let lock = NSLock()
        var opCalls = 0
        var results: [Int] = []

        coordinator.run(operation: { finish in
            lock.lock()
            opCalls += 1
            let isFirst = (opCalls == 1)
            lock.unlock()

            if isFirst { opCalledOnce.fulfill() }

            DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) {
                finish(42)
            }
        }, completion: { value in
            lock.lock(); results.append(value); lock.unlock()
            done.fulfill()
        })

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            coordinator.run(operation: { _ in
                XCTFail("operation must not be called while already running")
            }, completion: { value in
                lock.lock(); results.append(value); lock.unlock()
                done.fulfill()
            })
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.02) {
            coordinator.run(operation: { _ in
                XCTFail("operation must not be called while already running")
            }, completion: { value in
                lock.lock(); results.append(value); lock.unlock()
                done.fulfill()
            })
        }

        wait(for: [opCalledOnce, done], timeout: 2.0)

        lock.lock()
        let calls = opCalls
        let allSame = results.allSatisfy { $0 == 42 }
        let count = results.count
        lock.unlock()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(count, 3)
        XCTAssertTrue(allSame)
    }

    /// test_4: run (without completion) → still performs operation and does not crash
    func test_4_run_withoutCompletion_stillPerformsOperation() {
        let coordinator = makeCoordinator() as UpdateCoordinator<Void>

        let opCalled = expectation(description: "operation called")
        let finished = expectation(description: "operation finished")

        coordinator.run(operation: { finish in
            opCalled.fulfill()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) {
                finish(())
                finished.fulfill()
            }
        })

        wait(for: [opCalled, finished], timeout: 1.0)
    }

    /// test_5: run (reentrant from completion) → starts a new operation after finish and does not lose callbacks
    func test_5_run_reentrantFromCompletion_startsNewOperationAfterFinish() {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>

        let firstDone = expectation(description: "first completion called")
        let secondDone = expectation(description: "second completion called")

        let lock = NSLock()
        var opCalls = 0
        var received: [Int] = []

        coordinator.run(operation: { finish in
            lock.lock(); opCalls += 1; lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) { finish(1) }
        }, completion: { value in
            lock.lock(); received.append(value); lock.unlock()
            firstDone.fulfill()

            coordinator.run(operation: { finish in
                lock.lock(); opCalls += 1; lock.unlock()
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) { finish(2) }
            }, completion: { v2 in
                lock.lock(); received.append(v2); lock.unlock()
                secondDone.fulfill()
            })
        })

        wait(for: [firstDone, secondDone], timeout: 2.0)

        lock.lock()
        let calls = opCalls
        let values = received
        lock.unlock()

        XCTAssertEqual(calls, 2)
        XCTAssertEqual(values, [1, 2])
    }

    /// test_6: run (many concurrent callers) → still runs exactly once and delivers to all
    func test_6_run_manyConcurrentCallers_runsExactlyOnce_andDeliversToAll() {
        let coordinator = makeCoordinator() as UpdateCoordinator<Int>

        let callers = 200
        let done = expectation(description: "all completions called")
        done.expectedFulfillmentCount = callers

        let opCalledOnce = expectation(description: "operation called once")
        opCalledOnce.expectedFulfillmentCount = 1

        let startGate = DispatchGroup()
        let lock = NSLock()

        var opCalls = 0
        var receivedCount = 0
        var minValue = Int.max
        var maxValue = Int.min

        for _ in 0..<callers {
            startGate.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                coordinator.run(operation: { finish in
                    lock.lock()
                    opCalls += 1
                    let isFirst = (opCalls == 1)
                    lock.unlock()

                    if isFirst { opCalledOnce.fulfill() }

                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                        finish(999)
                    }
                }, completion: { value in
                    lock.lock()
                    receivedCount += 1
                    minValue = Swift.min(minValue, value)
                    maxValue = Swift.max(maxValue, value)
                    lock.unlock()

                    done.fulfill()
                })
                startGate.leave()
            }
        }

        startGate.wait()

        wait(for: [opCalledOnce, done], timeout: 5.0)

        lock.lock()
        let calls = opCalls
        let rCount = receivedCount
        let minV = minValue
        let maxV = maxValue
        lock.unlock()

        XCTAssertEqual(calls, 1)
        XCTAssertEqual(rCount, callers)
        XCTAssertEqual(minV, 999)
        XCTAssertEqual(maxV, 999)
    }
}

