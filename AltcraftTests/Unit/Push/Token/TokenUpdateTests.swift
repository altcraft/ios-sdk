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
 *  - test_2: tokenUpdate → emits ErrorEvent and completes with false when current token is nil.
 *  - test_3: tokenUpdate → completes early and does not set currentToken when no saved token.
 *  - test_4: tokenUpdate → sets currentToken from TokenManager (manual token) and does not overwrite saved token on Retry/Error.
 *  - test_5: tokenUpdate → completes when saved and current are equal and sets currentToken.
 *  - test_6: startUpdate → does not save token when RetryEvent returned.
 *  - test_7: startUpdate → does not save token when ErrorEvent returned (if it happens).
 */
final class TokenUpdateTests: IsolatedTestCase {

    private var originalGroup: String?

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] in self?.events.append($0) } }
        func stop() { SDKEvents.shared.unsubscribe() }
    }

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

    private func setSavedToken(provider: String?, token: String?) {
        StoredVariablesManager.shared.setCurrentToken(provider: provider, token: token)
    }

    private func setManualToken(provider: String, token: String) {
        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    private func initSDK(apiUrl: String = "https://api.example.com", rToken: String? = nil) {
        let builder = AltcraftConfiguration.Builder()
            .setApiUrl(apiUrl)
            .setRToken(rToken)
            .setEnableLogging(false)

        let config = builder.build()

        let exp = expectation(description: "initSDK completion")
        AltcraftInit.shared.initSDK(configuration: config) { _ in
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    override func setUp() {
        super.setUp()
        setTestAppGroup()
        clearAllTokens()
        initSDK(apiUrl: "https://api.example.com", rToken: nil)
    }

    override func tearDown() {
        clearAllTokens()
        restoreAppGroup()
        super.tearDown()
    }

    /// test_1: sendUpdateRequest → returns RetryEvent when data/request cannot be built
    func test_1_sendUpdateRequest_returnsRetryEvent_whenDataMissing() {
        let exp = expectation(description: "sendUpdateRequest completion")
        TokenUpdate.shared.sendUpdateRequest { ev in
            XCTAssertTrue(ev is RetryEvent)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    /// test_2: tokenUpdate → emits ErrorEvent and completes with false when current token is nil
    func test_2_tokenUpdate_whenCurrentTokenIsNil_emitsError_andCompletesFalse() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        StoredVariablesManager.shared.clearManualToken()
        TokenManager.shared.tokens.ts_removeAll()
        setSavedToken(provider: "apns", token: "OLD-TOKEN")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { ok in
            XCTAssertFalse(ok)
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        XCTAssertTrue(spy.events.contains { $0 is ErrorEvent })
        XCTAssertNil(TokenUpdate.shared.currentToken)
    }

    /// test_3: tokenUpdate → completes early and does not set currentToken when no saved token
    func test_3_tokenUpdate_completesEarly_whenNoSavedToken_andDoesNotSetCurrentToken() {
        clearAllTokens()
        initSDK(apiUrl: "https://api.example.com", rToken: "rTok123")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        XCTAssertNil(TokenUpdate.shared.currentToken)
    }

    /// test_4: tokenUpdate → sets currentToken from TokenManager (manual token) and does not overwrite saved token on Retry/Error
    func test_4_tokenUpdate_setsCurrentToken_and_doesNotOverwriteSavedToken_onRetryOrError() {
        setSavedToken(provider: "apns", token: "OLD-TOKEN")
        setManualToken(provider: "ios-firebase", token: "NEW-TOKEN")

        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { _ in exp.fulfill() }
        waitForExpectations(timeout: 3.0)

        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "NEW-TOKEN")

        let saved = StoredVariablesManager.shared.getSavedToken()
        let hasRetry = spy.events.contains { $0 is RetryEvent }
        let hasError = spy.events.contains { $0 is ErrorEvent }

        if hasRetry || hasError {
            XCTAssertEqual(saved?.provider, "apns")
            XCTAssertEqual(saved?.token, "OLD-TOKEN")
        } else {
            XCTAssertEqual(saved?.provider, "ios-firebase")
            XCTAssertEqual(saved?.token, "NEW-TOKEN")
        }
    }

    /// test_5: tokenUpdate → completes when saved and current are equal and sets currentToken
    func test_5_tokenUpdate_completes_whenTokensEqual_andSetsCurrentToken() {
        setSavedToken(provider: "ios-firebase", token: "SAME")
        setManualToken(provider: "ios-firebase", token: "SAME")

        let exp = expectation(description: "tokenUpdate completion")
        TokenUpdate.shared.tokenUpdate { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        let current = TokenUpdate.shared.currentToken
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, "ios-firebase")
        XCTAssertEqual(current?.token, "SAME")

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertEqual(saved?.provider, "ios-firebase")
        XCTAssertEqual(saved?.token, "SAME")
    }

    /// test_6: startUpdate → does not save token when RetryEvent returned
    func test_6_startUpdate_doesNotSaveToken_onRetryEvent() {
        setSavedToken(provider: "apns", token: "OLD")
        TokenUpdate.shared.currentToken = TokenData(provider: "ios-firebase", token: "NEW")

        let exp = expectation(description: "startUpdate completion")
        TokenUpdate.shared.startUpdate { ok in
            XCTAssertFalse(ok)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertEqual(saved?.provider, "apns")
        XCTAssertEqual(saved?.token, "OLD")
    }

    /// test_7: startUpdate → does not save token when ErrorEvent returned (if it happens)
    func test_7_startUpdate_doesNotSaveToken_onErrorEvent_ifItHappens() {
        setSavedToken(provider: "apns", token: "OLD")
        TokenUpdate.shared.currentToken = TokenData(provider: "ios-firebase", token: "NEW")

        let spy = EventSpy(); spy.start(); defer { spy.stop() }

        let exp = expectation(description: "startUpdate completion")
        TokenUpdate.shared.startUpdate { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 3.0)

        if spy.events.contains(where: { $0 is ErrorEvent }) {
            let saved = StoredVariablesManager.shared.getSavedToken()
            XCTAssertEqual(saved?.provider, "apns")
            XCTAssertEqual(saved?.token, "OLD")
        }
    }

}

