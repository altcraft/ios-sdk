//
//  InitBarrierTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * InitBarrierTests
 *
 * Positive scenarios:
 * - test_1: InitGate.complete completes gate and resumes all waiters exactly once.
 * - test_2: InitBarrier.reserve returns same gate while current gate is not completed.
 * - test_3: InitBarrier.reserve returns new gate after previous gate is completed.
 * - test_4: awaitInit completes immediately when gate is already completed.
 * - test_5: awaitInit waits and completes when gate completes before timeout.
 * - test_6: awaitInit returns after timeout when gate is not completed.
 * - test_7: withInitReady executes block after gate completion.
 * - test_8: withInitReady executes block immediately when gate is already completed.
 *
 */
final class InitBarrierTests: IsolatedTestCase {

    override func setUp() async throws {
        try await super.setUp()
        _ = await resetSharedBarrierToFreshGate()
    }

    private func waitShort(_ seconds: TimeInterval = 0.05) async {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }

    private func gateCompleted(_ gate: InitGate) async -> Bool {
        await gate.completed()
    }

    @discardableResult
    private func resetSharedBarrierToFreshGate() async -> InitGate {
        let current = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(current)
        await waitShort(0.01)

        var fresh = await InitBarrier.shared.reserve()
        var attempts = 0

        while attempts < 5 {
            let isCompleted = await gateCompleted(fresh)
            if !isCompleted {
                break
            }

            await InitBarrier.shared.complete(fresh)
            await waitShort(0.01)
            fresh = await InitBarrier.shared.reserve()
            attempts += 1
        }

        let finalCompleted = await gateCompleted(fresh)
        XCTAssertFalse(
            finalCompleted,
            "resetSharedBarrierToFreshGate(): expected fresh gate to be NOT completed"
        )

        return fresh
    }

    /// test_1: InitGate.complete completes gate and resumes all waiters exactly once
    func test_1_InitGate_complete_completesGate_andResumesAllWaitersExactlyOnce() async {
        let gate = InitGate()
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await gate.wait()
                await counter.increment()
            }

            group.addTask {
                await gate.wait()
                await counter.increment()
            }

            await waitShort(0.01)
            await gate.complete()
        }

        let isCompleted = await gateCompleted(gate)
        let resumedCount = await counter.value()

        XCTAssertTrue(isCompleted)
        XCTAssertEqual(resumedCount, 2)

        let before = await counter.value()
        await gate.wait()
        let afterImmediateWait = await counter.value()

        XCTAssertEqual(before, afterImmediateWait)

        await gate.complete()
        let finalCount = await counter.value()
        XCTAssertEqual(finalCount, 2)
    }

    /// test_2: InitBarrier.reserve returns same gate while current gate is not completed
    func test_2_InitBarrier_reserve_returnsSameGate_whileCurrentGateIsNotCompleted() async {
        let base = await resetSharedBarrierToFreshGate()
        let baseCompleted = await gateCompleted(base)
        XCTAssertFalse(baseCompleted)

        let current = await InitBarrier.shared.current()
        let reserved1 = await InitBarrier.shared.reserve()
        let reserved2 = await InitBarrier.shared.reserve()
        let reserved1Completed = await gateCompleted(reserved1)

        XCTAssertTrue(current === base)
        XCTAssertTrue(current === reserved1)
        XCTAssertTrue(reserved1 === reserved2)
        XCTAssertFalse(reserved1Completed)
    }

    /// test_3: InitBarrier.reserve returns new gate after previous gate is completed
    func test_3_InitBarrier_reserve_returnsNewGate_afterPreviousGateIsCompleted() async {
        let first = await resetSharedBarrierToFreshGate()
        let firstCompletedBefore = await gateCompleted(first)
        XCTAssertFalse(firstCompletedBefore)

        await InitBarrier.shared.complete(first)
        await waitShort(0.02)

        let firstCompletedAfter = await gateCompleted(first)
        XCTAssertTrue(firstCompletedAfter)

        let second = await InitBarrier.shared.reserve()
        let secondCompleted = await gateCompleted(second)

        XCTAssertFalse(first === second)
        XCTAssertFalse(secondCompleted)
    }

    /// test_4: awaitInit completes immediately when gate is already completed
    func test_4_awaitInit_completesImmediately_whenGateIsAlreadyCompleted() async {
        let gate = InitGate()
        await gate.complete()
        await waitShort(0.01)

        let start = Date()
        await awaitInit(
            function: "test_4",
            gate: gate,
            timeoutMs: 200
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 1.0)
    }

    /// test_5: awaitInit waits and completes when gate completes before timeout
    func test_5_awaitInit_waits_andCompletes_whenGateCompletesBeforeTimeout() async {
        let gate = InitGate()

        async let waiter: Void = awaitInit(
            function: "test_5",
            gate: gate,
            timeoutMs: 500
        )

        try? await Task.sleep(nanoseconds: 50_000_000)
        await gate.complete()
        _ = await waiter

        let isCompleted = await gateCompleted(gate)
        XCTAssertTrue(isCompleted)
    }

    /// test_6: awaitInit returns after timeout when gate is not completed
    func test_6_awaitInit_returnsAfterTimeout_whenGateIsNotCompleted() async {
        let gate = InitGate()
        let finished = Flag()

        let task = Task {
            await awaitInit(
                function: "test_6",
                gate: gate,
                timeoutMs: 50
            )
            await finished.setTrue()
        }

        for _ in 0..<20 {
            if await finished.value() {
                break
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        let didFinish = await finished.value()
        task.cancel()

        XCTAssertTrue(didFinish)

        let isCompleted = await gateCompleted(gate)
        XCTAssertFalse(isCompleted)
    }

    /// test_7: withInitReady executes block after gate completion
    func test_7_withInitReady_executesBlock_afterGateCompletion() async {
        let gate = InitGate()
        let ran = Flag()

        async let task: Void = withInitReady(
            function: "test_7",
            gate: gate
        ) {
            await ran.setTrue()
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        let ranBeforeComplete = await ran.value()
        XCTAssertFalse(ranBeforeComplete)

        await gate.complete()
        _ = await task

        let isCompleted = await gateCompleted(gate)
        let ranAfterComplete = await ran.value()

        XCTAssertTrue(isCompleted)
        XCTAssertTrue(ranAfterComplete)
    }

    /// test_8: withInitReady executes block immediately when gate is already completed
    func test_8_withInitReady_executesBlockImmediately_whenGateIsAlreadyCompleted() async {
        let gate = InitGate()
        let ran = Flag()

        await gate.complete()
        await waitShort(0.01)

        await withInitReady(
            function: "test_8",
            gate: gate
        ) {
            await ran.setTrue()
        }

        let didRun = await ran.value()
        XCTAssertTrue(didRun)
    }
}

private actor Counter {
    private var storage = 0

    func increment() {
        storage += 1
    }

    func value() -> Int {
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
