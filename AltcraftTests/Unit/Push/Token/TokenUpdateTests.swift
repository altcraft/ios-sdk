//
//  TokenUpdateTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * TokenUpdateTests
 *
 * Positive scenarios:
 *  - test_1: sendUpdateRequest → returns RetryEvent when data/request cannot be built.
 *  - test_2: tokenUpdate → emits ErrorEvent and completes when current token is nil.
 *  - test_3: tokenUpdate → sets currentToken and attempts update when saved and current differ.
 *  - test_4: tokenUpdate → completes when saved and current are equal.
 */
final class TokenUpdateTests: IsolatedTestCase {

    private var originalGroup: String?

    private func setTestAppGroup() {
        originalGroup = StoredVariablesManager.shared.getGroupName()
        StoredVariablesManager.shared.setGroupsName(
            value: "group.altcraft.tests.tokenupdate.\(UUID().uuidString)"
        )
    }

    private func restoreAppGroup() {
        StoredVariablesManager.shared.setGroupsName(value: originalGroup)
    }

    private func clearAllTokens() {
        let user = StoredVariablesManager.shared
        user.clearManualToken()
        user.clearSavedToken()
        TokenUpdate.shared.currentToken = nil
        TokenManager.shared.tokens.ts_removeAll()
    }

    private func setSavedToken(provider: String, token: String) {
        StoredVariablesManager.shared.setCurrentToken(provider: provider, token: token)
    }

    private func setManualToken(provider: String, token: String) {
        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    private func normalizedFunc(_ s: String?) -> String? {
        guard let s = s else { return nil }
        if let idx = s.firstIndex(of: "(") { return String(s[..<idx]) }
        return s.hasSuffix("()") ? String(s.dropLast(2)) : s
    }

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

    /// test_1: sendUpdateRequest returns RetryEvent when request data cannot be built
    func test_1_sendUpdateRequest_returnsRetryEvent_whenDataMissing() {
        let exp = expectation(description: "sendUpdateRequest completion")
        TokenUpdate.shared.sendUpdateRequest { ev in
            XCTAssertTrue(ev is RetryEvent)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    /// test_2: tokenUpdate emits ErrorEvent and completes when current token is nil
    func test_2_tokenUpdate_whenCurrentTokenIsNil_emitsError_andCompletes() {
        var captured: [Event] = []
        SDKEvents.shared.subscribe { captured.append($0) }
        defer { SDKEvents.shared.unsubscribe() }

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { exp.fulfill() }
        waitForExpectations(timeout: 3.0)

        XCTAssertFalse(captured.isEmpty)
        XCTAssertTrue(captured.last is ErrorEvent)
        XCTAssertEqual(self.normalizedFunc(captured.last?.function), "tokenUpdate")
    }

    /// test_3: tokenUpdate sets currentToken and attempts update when tokens differ
    func test_3_tokenUpdate_setsCurrentToken_and_attemptsUpdate_whenTokensDiffer() {
        setSavedToken(provider: "apns", token: "OLD-TOKEN")
        setManualToken(provider: "ios-firebase", token: "NEW-TOKEN")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { exp.fulfill() }
        waitForExpectations(timeout: 3.0)

        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "NEW-TOKEN")

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertEqual(saved?.provider, "apns")
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_4: tokenUpdate completes without update when tokens are equal
    func test_4_tokenUpdate_completes_whenTokensEqual() {
        setSavedToken(provider: "ios-firebase", token: "SAME")
        setManualToken(provider: "ios-firebase", token: "SAME")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { exp.fulfill() }
        waitForExpectations(timeout: 3.0)

        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "SAME")

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertEqual(saved?.provider, "ios-firebase")
        XCTAssertEqual(saved?.token, "SAME")
    }
}
