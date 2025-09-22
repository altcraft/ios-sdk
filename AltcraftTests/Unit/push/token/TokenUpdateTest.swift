//
//  TokenUpdateTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * TokenUpdateTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_3_tokenUpdate_setsCurrentToken_and_attemptsUpdate_whenTokensDiffer
 *  - test_4_tokenUpdate_completes_whenTokensEqual
 *
 * Edge:
 *  - test_1_sendUpdateRequest_returnsRetryEvent_whenDataMissing
 *  - test_2_tokenUpdate_whenCurrentTokenIsNil_emitsError_andCompletes
 *
 * Notes:
 *  - No network seams required; the "missing data" path returns RetryEvent.
 *  - UserDefaults isolated by setting a temporary App Group in setUp/tearDown.
 */
final class TokenUpdateTests: XCTestCase {

    // MARK: - Helpers

    private var originalGroup: String?

    private func setTestAppGroup() {
        // Use a unique test app group for isolation (backed by standard on tests)
        originalGroup = StoredVariablesManager.shared.getGroupName()
        StoredVariablesManager.shared.setGroupsName(value: "group.altcraft.tests.\(UUID().uuidString)")
    }

    private func restoreAppGroup() {
        StoredVariablesManager.shared.setGroupsName(value: originalGroup)
    }

    private func clearAllTokens() {
        let user = StoredVariablesManager.shared
        user.clearManualToken()
        user.clearSavedToken()
        // Also reset retry counters to a known value to avoid incidental state
        user.setUpdateRetryCount(value: 0)
    }

    private func setSavedToken(provider: String, token: String) {
        // Production code uses setCurrentToken() under-the-hood for the same key as "saved"
        StoredVariablesManager.shared.setCurrentToken(provider: provider, token: token)
    }

    private func setManualToken(provider: String, token: String) {
        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    private func normalizedFunc(_ s: String?) -> String? {
        guard let s = s else { return nil }
        return s.hasSuffix("()") ? String(s.dropLast(2)) : s
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        setTestAppGroup()
        clearAllTokens()
    }

    override func tearDown() {
        clearAllTokens()
        restoreAppGroup()
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_sendUpdateRequest_returnsRetryEvent_whenDataMissing
    func test_1_sendUpdateRequest_returnsRetryEvent_whenDataMissing() {
        let exp = expectation(description: "sendUpdateRequest completion")
        TokenUpdate.shared.sendUpdateRequest { ev in
            XCTAssertTrue(ev is RetryEvent, "Expected RetryEvent when UpdateRequestData is unavailable")
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    /// test_2_tokenUpdate_whenCurrentTokenIsNil_emitsError_andCompletes
    func test_2_tokenUpdate_whenCurrentTokenIsNil_emitsError_andCompletes() {
        // Ensure no manual token and no saved token
        clearAllTokens()

        var captured: [Event] = []
        SDKEvents.shared.subscribe { ev in captured.append(ev) }

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        // Expect an ErrorEvent from tokenUpdate() path (currentTokenIsNil)
        XCTAssertFalse(captured.isEmpty, "Expected at least one event")
        XCTAssertTrue(captured.last is ErrorEvent, "Expected ErrorEvent when current token is nil")
        XCTAssertEqual(self.normalizedFunc(captured.last?.function), "tokenUpdate")
    }

    /// test_3_tokenUpdate_setsCurrentToken_and_attemptsUpdate_whenTokensDiffer
    func test_3_tokenUpdate_setsCurrentToken_and_attemptsUpdate_whenTokensDiffer() {
        // Given: saved token (OLD) differs from current (manual) token (NEW)
        setSavedToken(provider: "apns", token: "OLD-TOKEN")
        setManualToken(provider: "ios-firebase", token: "NEW-TOKEN")

        // When
        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        // Then: TokenUpdate should capture the current token for update attempt
        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current, "currentToken should be set when manual token exists")
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "NEW-TOKEN")

        // Also verify retry counter was initialized (implementation sets it to 1 on update start).
        // We cannot distinguish "not set" vs default easily, but we can assert >= 1 after the call.
        let cnt = StoredVariablesManager.shared.getUpdateRetryCount() ?? 0
        XCTAssertGreaterThanOrEqual(cnt, 1, "Expected update retry count to be initialized")
    }

    /// test_4_tokenUpdate_completes_whenTokensEqual
    func test_4_tokenUpdate_completes_whenTokensEqual() {
        // Given: saved token equals current (manual) token
        setSavedToken(provider: "ios-firebase", token: "SAME")
        setManualToken(provider: "ios-firebase", token: "SAME")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate {
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        // currentToken captured
        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "SAME")
        // In equal path no update request is required; we only ensure flow completes.
    }
}

