//
//  TokenUpdateTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * TokenUpdateTests
 *
 * Positive scenarios:
 *  - test_1: request → returns RetryEvent when request data cannot be built.
 *  - test_2: tokenUpdateCheck → returns false when current token is unavailable.
 *  - test_3: tokenUpdateCheck → completes early when saved token is missing.
 *  - test_4: tokenUpdateCheck → sets currentToken from manual token and does not overwrite saved token on retry.
 *  - test_5: tokenUpdateCheck → completes early when saved and current tokens are equal.
 *  - test_6: tokenUpdate → returns false and does not overwrite saved token when update request fails.
 *  - test_7: tokenUpdateResult → returns false on RetryEvent and does not save current token.
 *
 */
final class TokenUpdateTests: IsolatedTestCase {

    private var originalGroup: String?

    private final class NilAPNSProvider: APNSInterface {
        func getToken(completion: @escaping (String?) -> Void) {
            completion(nil)
        }
    }

    private func initSDK(
        apiUrl: String = "https://api.example.com",
        rToken: String? = nil
    ) async  {
        let builder = AltcraftConfiguration.Builder()
            .setApiUrl(apiUrl)
            .setRToken(rToken)
            .setEnableLogging(false)

        _ = await AltcraftInit.shared.initSDK(
            configuration: builder.build()
        )
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

    private func clearAllTokens() async {
        await StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
        await TokenUpdate.shared.test_token_update_set_current_token(nil)
        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setAPNSProvider(nil)
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
    }

    private func setSavedToken(provider: String?, token: String?) {
        StoredVariablesManager.shared.setCurrentToken(provider: provider, token: token)
    }

    private func setManualToken(provider: String, token: String) async {
        await StoredVariablesManager.shared.setPushToken(
            provider: provider,
            token: token
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        setTestAppGroup()
    }

    override func setUp() async throws {
        try await super.setUp()
        await clearAllTokens()
        await initSDK(apiUrl: "https://api.example.com", rToken: nil)
    }

    override func tearDown() async throws {
        await clearAllTokens()
        restoreAppGroup()
        try await super.tearDown()
    }

    /// test_1: request returns RetryEvent when request data cannot be built
    func test_1_request_returnsRetryEvent_whenRequestDataCannotBeBuilt() async {
        setSavedToken(
            provider: Constants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await TokenUpdate.shared.test_token_update_set_current_token(
            TokenData(
                provider: Constants.ProviderName.firebase,
                token: "NEW-TOKEN"
            )
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let event = await TokenUpdate.shared.test_token_update_request()
        XCTAssertTrue(type(of: event) == RetryEvent.self)
    }

    /// test_2: tokenUpdateCheck returns false when current token is unavailable
    func test_2_tokenUpdateCheck_returnsFalse_whenCurrentTokenIsUnavailable() async {
        setSavedToken(
            provider: Constants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await StoredVariablesManager.shared.clearManualToken()
        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setAPNSProvider(NilAPNSProvider())
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)

        let result = await TokenUpdate.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await TokenUpdate.shared.test_token_update_current_token()
        let saved = StoredVariablesManager.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNil(current)
        XCTAssertEqual(saved?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_3: tokenUpdateCheck completes early when saved token is missing
    func test_3_tokenUpdateCheck_completesEarly_whenSavedTokenIsMissing() async {
        StoredVariablesManager.shared.clearSavedToken()
        await StoredVariablesManager.shared.clearManualToken()

        let result = await TokenUpdate.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await TokenUpdate.shared.test_token_update_current_token()
        let saved = StoredVariablesManager.shared.getSavedToken()

        XCTAssertTrue(result)
        XCTAssertNil(current)
        XCTAssertNil(saved)
    }

    /// test_4: tokenUpdateCheck sets currentToken from manual token and does not overwrite saved token on retry
    func test_4_tokenUpdateCheck_setsCurrentToken_andDoesNotOverwriteSavedToken_onRetry() async {
        setSavedToken(
            provider: Constants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await setManualToken(
            provider: Constants.ProviderName.firebase,
            token: "NEW-TOKEN"
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await TokenUpdate.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await TokenUpdate.shared.test_token_update_current_token()
        let saved = StoredVariablesManager.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW-TOKEN")
        XCTAssertEqual(saved?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_5: tokenUpdateCheck completes early when saved and current tokens are equal
    func test_5_tokenUpdateCheck_completesEarly_whenSavedAndCurrentTokensAreEqual() async {
        setSavedToken(
            provider: Constants.ProviderName.firebase,
            token: "SAME"
        )

        await setManualToken(
            provider: Constants.ProviderName.firebase,
            token: "SAME"
        )

        let result = await TokenUpdate.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await TokenUpdate.shared.test_token_update_current_token()
        let saved = StoredVariablesManager.shared.getSavedToken()

        XCTAssertTrue(result)
        XCTAssertNil(current)
        XCTAssertEqual(saved?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(saved?.token, "SAME")
    }

    /// test_6: tokenUpdate returns false and does not overwrite saved token when update request fails
    func test_6_tokenUpdate_returnsFalse_andDoesNotOverwriteSavedToken_whenUpdateRequestFails() async {
        setSavedToken(
            provider: Constants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await setManualToken(
            provider: Constants.ProviderName.firebase,
            token: "NEW-TOKEN"
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await TokenUpdate.shared.tokenUpdate(enableRetry: false)

        let current = await TokenUpdate.shared.test_token_update_current_token()
        let saved = StoredVariablesManager.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW-TOKEN")
        XCTAssertEqual(saved?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_7: tokenUpdateResult returns false on RetryEvent and does not save current token
    func test_7_tokenUpdateResult_returnsFalse_onRetryEvent_andDoesNotSaveCurrentToken() async {
        setSavedToken(
            provider: Constants.ProviderName.apns,
            token: "OLD"
        )

        await TokenUpdate.shared.test_token_update_set_current_token(
            TokenData(
                provider: Constants.ProviderName.firebase,
                token: "NEW"
            )
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await TokenUpdate.shared.test_token_update_result(
            enableRetry: false
        )

        let saved = StoredVariablesManager.shared.getSavedToken()
        let current = await TokenUpdate.shared.test_token_update_current_token()

        XCTAssertFalse(result)
        XCTAssertEqual(saved?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD")
        XCTAssertEqual(current?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW")
    }
}
