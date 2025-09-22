//
//  ClearCacheTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ClearCacheTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_cancelAll_preventsScheduledWorkFromRunning
 *  - test_2_resetsUserDefaultsAndTokens_onSuccess
 *  - test_3_doesNothing_whenDbHasCriticalError
 *
 * Notes:
 *  - We point StoredVariablesManager to an isolated UserDefaults suite (UserDefaultsSandbox).
 *  - We schedule the exact DispatchWorkItem saved via RetryManager.store(...) so that
 *    RetryManager.cancelAll() actually cancels what would be executed.
 */
final class ClearCacheTests: XCTestCase {

    private var sandbox: UserDefaultsSandbox!

    override func setUp() {
        super.setUp()
        sandbox = UserDefaultsSandbox()
        // Make SDK use the sandboxed suite for token storage
        StoredVariablesManager.shared.setGroupsName(value: sandbox.suiteName)
        // Ensure DB is not marked as critical by default
        StoredVariablesManager.shared.setCritDB(value: false)
    }

    override func tearDown() {
        // Clean up any scheduled retry tasks between tests
        RetryManager.shared.cancelAll()
        sandbox.clear()
        sandbox = nil
        super.tearDown()
    }

    // MARK: - 1. cancelAll stops scheduled work

    /// clearCache() must call RetryManager.cancelAll(), preventing scheduled work from running.
    func test_1_cancelAll_preventsScheduledWorkFromRunning() {
        let ran = AtomicInt()

        // Prepare a cancellable work item and schedule it with a small delay
        let work = DispatchWorkItem { ran.increment() }
        RetryManager.shared.store(key: "T", work: work)
        RetryManager.shared.subscribeQueue.asyncAfter(deadline: .now() + 0.08, execute: work)

        let exp = expectation(description: "clearCache completion")
        clearCache {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        // Give a little time to ensure the scheduled work would have fired if not cancelled
        let settle = expectation(description: "settle")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.12) { settle.fulfill() }
        wait(for: [settle], timeout: 1.0)

        XCTAssertEqual(ran.value, 0, "Scheduled work should be cancelled by clearCache()")
    }

    // MARK: - 2. Resets persisted values and tokens

    /// On success, clearCache() must reset retry counters and remove saved/manual tokens.
    func test_2_resetsUserDefaultsAndTokens_onSuccess() {
        let store = StoredVariablesManager.shared

        // Seed non-default values
        store.setSubRetryCount(value: 5)
        store.setUpdateRetryCount(value: 7)
        store.setPushEventRetryCount(value: 3)

        // Seed tokens (manual + "current")
        store.setPushToken(provider: "apns", token: "MANUAL_TOKEN_123")
        store.setCurrentToken(provider: "apns", token: "CURRENT_TOKEN_456")
        TokenUpdate.shared.currentToken = TokenData(provider: "apns", token: "TMP")

        // Sanity: values are present before clear
        XCTAssertEqual(store.getSubRetryCount(), 5)
        XCTAssertEqual(store.getUpdateRetryCount(), 7)
        XCTAssertEqual(store.getPushEventRetryCount(), 3)
        XCTAssertNotNil(store.getManualToken())
        XCTAssertNotNil(store.getSavedToken())
        XCTAssertNotNil(TokenUpdate.shared.currentToken)

        let exp = expectation(description: "clearCache completion")
        clearCache {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        // Retry counters should be reset to 0 (our implementation writes zeros explicitly)
        XCTAssertEqual(StoredVariablesManager.shared.getSubRetryCount(), 0)
        XCTAssertEqual(StoredVariablesManager.shared.getUpdateRetryCount(), 0)
        XCTAssertEqual(StoredVariablesManager.shared.getPushEventRetryCount(), 0)

        // Tokens should be cleared
        XCTAssertNil(StoredVariablesManager.shared.getManualToken())
        XCTAssertNil(StoredVariablesManager.shared.getSavedToken())
        XCTAssertNil(TokenUpdate.shared.currentToken)
    }

    // MARK: - 3. Critical DB flag short-circuits (no completion)

    /// If DB is marked critical, clearCache() should skip work and not call completion.
    func test_3_doesNothing_whenDbHasCriticalError() {
        let store = StoredVariablesManager.shared
        store.setCritDB(value: true)

        // Seed a value we expect to remain unchanged
        store.setSubRetryCount(value: 9)

        // Use an inverted expectation to assert that completion is NOT called
        let exp = expectation(description: "no completion when critical DB")
        exp.isInverted = true

        clearCache {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 0.5)

        // Value should remain unchanged because the function returns early
        XCTAssertEqual(store.getSubRetryCount(), 9)
    }
}

// MARK: - Tiny atomic helper

private final class AtomicInt {
    private var _v: Int32 = 0
    func increment() { OSAtomicIncrement32(&_v) }
    var value: Int { Int(OSAtomicAdd32(0, &_v)) }
}

