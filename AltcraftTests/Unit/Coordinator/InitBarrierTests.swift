//
//  InitBarrierTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * InitBarrierTests
 *
 * Positive scenarios:
 *  - test_1: InitGate → completes and runs all waiters exactly once.
 *  - test_2: InitBarrier.reserve → returns same gate while initialization is not completed.
 *  - test_3: InitBarrier.reserve → returns new gate after previous gate is completed.
 *  - test_4: awaitInit → completes immediately when gate is already completed.
 *  - test_5: awaitInit → waits and completes when gate completes before timeout.
 *  - test_6: awaitInit → completes on timeout when gate is not completed.
 *  - test_7: withInitReady → executes block after gate completion.
 *  - test_8: withInitReady → executes block immediately when gate is already completed.
 */
final class InitBarrierTests: XCTestCase {

    // MARK: - Helpers

    private func waitShort(
        _ seconds: TimeInterval = 0.05,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exp = expectation(description: "waitShort")
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { exp.fulfill() }
        wait(for: [exp], timeout: seconds + 1.0)
    }

    private func gateCompletedSync(_ gate: InitGate) -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var done = false
        gate.completedSnapshot { v in
            done = v
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 1.0)
        return done
    }

    /// Brings `InitBarrier.shared` to a predictable state before a test:
    /// completes the current gate and reserves a new gate that is not completed.
    @discardableResult
    private func resetSharedBarrierToFreshGate(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> InitGate {
        let current = InitBarrier.shared.current()
        InitBarrier.shared.complete(current)
        waitShort(0.01)

        var fresh = InitBarrier.shared.reserve()

        var attempts = 0
        while gateCompletedSync(fresh) && attempts < 5 {
            InitBarrier.shared.complete(fresh)
            waitShort(0.01)
            fresh = InitBarrier.shared.reserve()
            attempts += 1
        }

        XCTAssertFalse(
            gateCompletedSync(fresh),
            "resetSharedBarrierToFreshGate(): expected fresh gate to be NOT completed",
            file: file,
            line: line
        )
        return fresh
    }

    // MARK: - XCTest lifecycle

    override func setUp() {
        super.setUp()
        _ = resetSharedBarrierToFreshGate()
    }

    // MARK: - Tests

    /// test_1: InitGate completes and runs waiters once
    func test_1_InitGate_complete_runsWaitersOnce() {
        let gate = InitGate()

        let exp1 = expectation(description: "waiter1")
        let exp2 = expectation(description: "waiter2")

        gate.addWaiter { exp1.fulfill() }
        gate.addWaiter { exp2.fulfill() }

        gate.complete()
        wait(for: [exp1, exp2], timeout: 1.0)

        XCTAssertTrue(gateCompletedSync(gate))

        var fired = 0
        let exp3 = expectation(description: "waiterAfterComplete")
        gate.addWaiter {
            fired += 1
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 1.0)
        XCTAssertEqual(fired, 1)

        gate.complete()
        waitShort()
        XCTAssertEqual(fired, 1)
    }

    /// test_2: InitBarrier reserve returns same gate while not completed
    func test_2_InitBarrier_reserve_returnsSameGate_whenNotCompleted() {
        let base = resetSharedBarrierToFreshGate()
        XCTAssertFalse(gateCompletedSync(base))

        let g1 = InitBarrier.shared.current()
        let r1 = InitBarrier.shared.reserve()

        XCTAssertTrue(g1 === r1, "Expected reserve() to return same gate while not completed")
        XCTAssertTrue(g1 === base, "Expected current() to be the fresh baseline gate")
        XCTAssertFalse(gateCompletedSync(r1))

        let r2 = InitBarrier.shared.reserve()
        XCTAssertTrue(r1 === r2, "Expected repeated reserve() to return same gate while not completed")
    }

    /// test_3: InitBarrier reserve returns new gate after completion
    func test_3_InitBarrier_reserve_returnsNewGate_afterCompletion() {
        let g1 = resetSharedBarrierToFreshGate()
        XCTAssertFalse(gateCompletedSync(g1))

        InitBarrier.shared.complete(g1)
        waitShort(0.02)
        XCTAssertTrue(gateCompletedSync(g1))

        let g2 = InitBarrier.shared.reserve()
        XCTAssertFalse(g1 === g2, "Expected reserve() to return a NEW gate after completion of previous")
        XCTAssertFalse(gateCompletedSync(g2))
    }

    /// test_4: awaitInit completes immediately when gate is already completed
    func test_4_awaitInit_completesImmediately_whenGateCompleted() {
        let gate = InitGate()
        gate.complete()
        waitShort(0.01)

        let exp = expectation(description: "awaitInit completion")
        awaitInit(function: "test_4", gate: gate, timeoutMs: 200) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_5: awaitInit waits and completes when gate completes before timeout
    func test_5_awaitInit_completesAfterGateComplete_beforeTimeout() {
        let gate = InitGate()

        let exp = expectation(description: "awaitInit completion")
        awaitInit(function: "test_5", gate: gate, timeoutMs: 500) {
            exp.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            gate.complete()
        }

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(gateCompletedSync(gate))
    }

    /// test_6: awaitInit completes on timeout when gate not completed
    func test_6_awaitInit_completesOnTimeout_whenGateNotCompleted() {
        let gate = InitGate()

        let exp = expectation(description: "awaitInit completion")
        awaitInit(function: "test_6", gate: gate, timeoutMs: 50) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
        XCTAssertFalse(gateCompletedSync(gate))
    }

    /// test_7: withInitReady runs block after gate completion
    func test_7_withInitReady_runsBlock_afterGateComplete() {
        let gate = InitGate()
        let exp = expectation(description: "withInitReady block")

        withInitReady(function: "test_7", gate: gate) {
            exp.fulfill()
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            gate.complete()
        }

        wait(for: [exp], timeout: 1.0)
        XCTAssertTrue(gateCompletedSync(gate))
    }

    /// test_8: withInitReady runs block immediately when gate already completed
    func test_8_withInitReady_runsBlockImmediately_whenGateCompleted() {
        let gate = InitGate()
        gate.complete()
        waitShort(0.01)

        let exp = expectation(description: "withInitReady block")
        withInitReady(function: "test_8", gate: gate) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}

