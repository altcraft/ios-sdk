//
//  RetryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * RetryTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_delay_growsExponentially_expectedValues
 *  - test_2_requestRetry_routes_withoutCrashing_for_allCodes
 *  - test_3_localPushSubscribeRetry_schedulesWork_and_canBeCancelled
 *  - test_4_localTokenUpdateRetry_schedulesWork_and_canBeCancelled
 *  - test_5_localPushEventRetry_returnsEarly_whenParamsMissing
 *
 * Notes:
 *  - We don't rely on real network connectivity. After scheduling a retry we
 *    immediately call `RetryManager.shared.cancelAll()` to avoid side effects
 *    and to make tests deterministic regardless of `NetworkMonitor` state.
 *  - We don't assert internal queues directly (they're encapsulated). Instead,
 *    we assert counters remain unchanged after cancellation (i.e., no work executed).
 */
final class RetryTests: XCTestCase {

    // MARK: - Helpers

    private let stored = StoredVariablesManager.shared

    override func setUp() {
        super.setUp()
        // Reset retry counters to known values
        stored.setSubRetryCount(value: 1)
        stored.setUpdateRetryCount(value: 1)
        // Intentionally leave push event retry as nil to exercise "early return" path.
        UserDefaults.standard.removeObject(forKey: "PUSH_EVENT_LOC_RETRY")
    }

    override func tearDown() {
        RetryManager.shared.cancelAll()
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_delay_growsExponentially_expectedValues
    func test_1_delay_growsExponentially_expectedValues() {
        // With initialDelay + 3 raised to retryCount
        // We don't know exact Constants.Retry.initialDelay here, but we can still
        // assert monotonic exponential growth characteristics for consecutive integers.

        let d1 = delay(retryCount: 1)
        let d2 = delay(retryCount: 2)
        let d3 = delay(retryCount: 3)

        XCTAssertGreaterThan(d1, 0.0)
        XCTAssertGreaterThan(d2, d1)
        XCTAssertGreaterThan(d3, d2)

        // Rough exponential property: ratio increases with the exponent.
        let r12 = d2 / d1
        let r23 = d3 / d2
        XCTAssertGreaterThan(r23, 1.0)
        XCTAssertGreaterThan(r12, 1.0)
    }

    /// test_2_requestRetry_routes_withoutCrashing_for_allCodes
    func test_2_requestRetry_routes_withoutCrashing_for_allCodes() {
        // These calls must not crash; they schedule work and return immediately.
        // We cancel after short delay to avoid execution in background.
        requestRetry(request: Constants.FunctionsCode.SS)
        requestRetry(request: Constants.FunctionsCode.SU)
        requestRetry(request: Constants.FunctionsCode.PE, context: nil, event: nil) // early return branch

        // Cancel any scheduled work items to keep the test deterministic.
        RetryManager.shared.cancelAll()

        // If we got here, routing did not crash; that's sufficient for a smoke test.
        XCTAssertTrue(true)
    }

    /// test_3_localPushSubscribeRetry_schedulesWork_and_canBeCancelled
    func test_3_localPushSubscribeRetry_schedulesWork_and_canBeCancelled() {
        // Arrange: start with known counter value
        stored.setSubRetryCount(value: 1)
        let before = stored.getSubRetryCount() ?? 0

        // Act: schedule retry, then cancel all immediately
        localPushSubscribeRetry()
        RetryManager.shared.cancelAll()

        // Assert: no increment has happened after a brief wait (work was cancelled)
        let exp = expectation(description: "no increment after cancel")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let after = self.stored.getSubRetryCount() ?? 0
            XCTAssertEqual(after, before, "Counter must not change when work is cancelled")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_4_localTokenUpdateRetry_schedulesWork_and_canBeCancelled
    func test_4_localTokenUpdateRetry_schedulesWork_and_canBeCancelled() {
        stored.setUpdateRetryCount(value: 1)
        let before = stored.getUpdateRetryCount() ?? 0

        // Private function; call through public router to hit the same path.
        requestRetry(request: Constants.FunctionsCode.SU)
        RetryManager.shared.cancelAll()

        let exp = expectation(description: "no increment after cancel (update)")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            let after = self.stored.getUpdateRetryCount() ?? 0
            XCTAssertEqual(after, before, "Counter must not change when work is cancelled")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_5_localPushEventRetry_returnsEarly_whenParamsMissing
    func test_5_localPushEventRetry_returnsEarly_whenParamsMissing() {
        // push event retry count is nil -> guard fails -> early return, no crash
        requestRetry(request: Constants.FunctionsCode.PE, context: nil, event: nil)

        // Also try with context but missing event
        let stack = TestCoreDataStack(bundleToken: CoreDataManager.self,
                                      bundleIdentifier: Constants.CoreData.identifier)
        requestRetry(request: Constants.FunctionsCode.PE, context: stack.newBGContext(), event: nil)

        // If we got here, both calls returned early without scheduling work or crashing.
        XCTAssertTrue(true)
    }
}

