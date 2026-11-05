//
//  AsyncLazyTests.swift
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
 * AsyncLazyTests
 *
 * Positive scenarios:
 *  - test_1: get → loads value once and returns cached result on repeated calls.
 *  - test_2: get with concurrent callers → executes loader only once and shares result.
 *  - test_3: get with nil result → caches nil and does not reload until reset.
 *  - test_4: reset → clears cached value and forces reload on next get.
 *  - test_5: get after loader failure → resets to idle and allows successful retry.
 *  - test_6: reset during in-flight load → does not affect current waiters and next get reloads value.
 *  - test_7: reset while loading → the stale pre-reset result is never cached.
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

    /// Test error type.
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

    /// test_6: reset during in-flight load forgets the current task, starts a
    /// new load, and the stale pre-reset result is never cached.
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
        XCTAssertEqual(
            thirdResult,
            2,
            "Stale pre-reset result must not be cached"
        )
    }

    /// test_7: reset while loading — the stale result is returned to its
    /// caller but never written into the cache; the cache keeps only the
    /// value loaded after the reset.
    func test_7_reset_whileLoading_staleResultIsNotCached() async throws {
        let lazy = AsyncLazy<Int>()
        let counter = Counter()

        // Old load starts and stays in flight.
        async let stale: Int? = lazy.get {
            await counter.increment()
            try? await Task.sleep(nanoseconds: 100_000_000)
            return 1
        }

        try? await Task.sleep(nanoseconds: 20_000_000)

        // Reset while the old load is in flight.
        await lazy.reset()

        // New load after the reset.
        let fresh = try await lazy.get {
            await counter.increment()
            return 2
        }

        // The stale load still delivers its own value to its caller.
        let staleResult = try await stale
        XCTAssertEqual(staleResult, 1)

        // But it must not poison the cache: the fresh value stays.
        let cached = try await lazy.get {
            await counter.increment()
            return 3
        }

        let loadCount = await counter.get()

        XCTAssertEqual(fresh, 2)
        XCTAssertEqual(
            cached,
            2,
            "Stale pre-reset result must not be cached"
        )
        XCTAssertEqual(
            loadCount,
            2,
            "Cached value must not trigger another load"
        )
    }
}
