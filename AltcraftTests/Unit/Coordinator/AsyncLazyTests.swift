//
//  AsyncLazyTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * AsyncLazyTests
 *
 * Positive scenarios:
 *  - test_1: get → loads value once and returns cached result on repeated calls.
 *  - test_2: get with concurrent callers → executes loader only once and shares result.
 *  - test_3: get with nil result → caches nil and does not reload until reset.
 *  - test_4: reset → clears cached value and forces reload on next get.
 *  - test_5: get after loader failure → resets to idle and allows successful retry.
 *  - test_6: reset during in-flight load → does not affect current waiters and next get reloads value.
 *
 */
final class AsyncLazyTests: IsolatedTestCase {

    actor Counter {
        private var value = 0

        func increment() {
            value += 1
        }

        func get() -> Int {
            value
        }
    }

    enum TestError: Error, Equatable {
        case failed
    }

    /// test_1: get loads value once and returns cached result on repeated calls
    func test_1_get_loadsValueOnce_andReturnsCachedResult_onRepeatedCalls() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        let first = try await lazy.get {
            await counter.increment()
            return 1
        }

        let second = try await lazy.get {
            await counter.increment()
            return 2
        }

        let loadCount = await counter.get()

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 1)
        XCTAssertEqual(loadCount, 1)
    }

    /// test_2: get with concurrent callers executes loader only once and shares result
    func test_2_get_withConcurrentCallers_executesLoaderOnlyOnce_andSharesResult() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        var results: [Int?] = []

        try await withThrowingTaskGroup(of: Int?.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await lazy.get {
                        await counter.increment()
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        return 1
                    }
                }
            }

            for try await value in group {
                results.append(value)
            }
        }

        let loadCount = await counter.get()

        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(results.count, 20)
        XCTAssertTrue(results.allSatisfy { $0 == 1 })
    }

    /// test_3: get with nil result caches nil and does not reload until reset
    func test_3_get_withNilResult_cachesNil_andDoesNotReload_untilReset() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        let first = try await lazy.get {
            await counter.increment()
            return nil
        }

        let second = try await lazy.get {
            await counter.increment()
            return 42
        }

        let loadCount = await counter.get()

        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertEqual(loadCount, 1)
    }

    /// test_4: reset clears cached value and forces reload on next get
    func test_4_reset_clearsCachedValue_andForcesReload_onNextGet() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        let first = try await lazy.get {
            await counter.increment()
            return 1
        }

        await lazy.reset()

        let second = try await lazy.get {
            await counter.increment()
            return 2
        }

        let loadCount = await counter.get()

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 2)
        XCTAssertEqual(loadCount, 2)
    }

    /// test_5: get after loader failure resets to idle and allows successful retry
    func test_5_get_afterLoaderFailure_resetsToIdle_andAllowsSuccessfulRetry() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        do {
            _ = try await lazy.get {
                await counter.increment()
                throw TestError.failed
            }
            XCTFail("Expected loader to throw")
        } catch let error as TestError {
            XCTAssertEqual(error, .failed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let value = try await lazy.get {
            await counter.increment()
            return 2
        }

        let loadCount = await counter.get()

        XCTAssertEqual(value, 2)
        XCTAssertEqual(loadCount, 2)
    }

    /// test_6: reset during in-flight load forgets current task, allows a new load,
    /// and both in-flight callers may observe different loaders
    func test_6_reset_duringInFlightLoad_forgetsCurrentTask_andAllowsNextGetToStartNewLoad() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        async let first: Int? = lazy.get {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 100_000_000)
            return 1
        }

        try? await Task.sleep(nanoseconds: 20_000_000)

        await lazy.reset()

        let secondResult = try await lazy.get {
            await counter.increment()
            return 2
        }

        let firstResult = try await first

        let thirdResult = try await lazy.get {
            await counter.increment()
            return 999
        }

        let loadCount = await counter.get()

        XCTAssertEqual(firstResult, 1)
        XCTAssertEqual(secondResult, 2)
        XCTAssertEqual(loadCount, 2)
        XCTAssertTrue(thirdResult == 1 || thirdResult == 2)
    }
}
