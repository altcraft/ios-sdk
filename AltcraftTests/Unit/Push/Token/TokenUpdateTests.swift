//
//  TokenUpdateTests.swift
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

    /// APNs provider mock returning no token.
    private final class NilAPNSProvider: APNSInterface {
        func getToken(completion: @escaping (String?) -> Void) {
            completion(nil)
        }
    }

    private func initSDK(
        apiUrl: String = "https://api.example.com",
        rToken: String? = nil
    ) async  {
        let builder = AltcraftConfiguration.Builder(
            apiUrl: apiUrl,
            rToken: rToken,
            enableLogging: false
        )

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
        await PushStoredVariables.shared.clearManualToken()
        PushStoredVariables.shared.clearSavedToken()
        await PushTokenProcess.shared.test_token_update_set_current_token(nil)
        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setAPNSProvider(nil)
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
    }

    private func setSavedToken(provider: String?, token: String?) {
        PushStoredVariables.shared.setCurrentToken(provider: provider, token: token)
    }

    private func setManualToken(provider: String, token: String) async {
        await PushStoredVariables.shared.setPushToken(
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
            provider: PushConstants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await PushTokenProcess.shared.test_token_update_set_current_token(
            TokenData(
                provider: PushConstants.ProviderName.firebase,
                token: "NEW-TOKEN"
            )
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let event = await PushTokenProcess.shared.test_token_update_request()
        XCTAssertTrue(type(of: event) == RetryEvent.self)
    }

    /// test_2: tokenUpdateCheck returns false when current token is unavailable
    func test_2_tokenUpdateCheck_returnsFalse_whenCurrentTokenIsUnavailable() async {
        setSavedToken(
            provider: PushConstants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await PushStoredVariables.shared.clearManualToken()
        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setAPNSProvider(NilAPNSProvider())
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)

        let result = await PushTokenProcess.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await PushTokenProcess.shared.test_token_update_current_token()
        let saved = PushStoredVariables.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNil(current)
        XCTAssertEqual(saved?.provider, PushConstants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_3: tokenUpdateCheck completes early when saved token is missing
    func test_3_tokenUpdateCheck_completesEarly_whenSavedTokenIsMissing() async {
        PushStoredVariables.shared.clearSavedToken()
        await PushStoredVariables.shared.clearManualToken()

        let result = await PushTokenProcess.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await PushTokenProcess.shared.test_token_update_current_token()
        let saved = PushStoredVariables.shared.getSavedToken()

        XCTAssertTrue(result)
        XCTAssertNil(current)
        XCTAssertNil(saved)
    }

    /// test_4: tokenUpdateCheck sets currentToken from manual token and does not overwrite saved token on retry
    func test_4_tokenUpdateCheck_setsCurrentToken_andDoesNotOverwriteSavedToken_onRetry() async {
        setSavedToken(
            provider: PushConstants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await setManualToken(
            provider: PushConstants.ProviderName.firebase,
            token: "NEW-TOKEN"
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await PushTokenProcess.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await PushTokenProcess.shared.test_token_update_current_token()
        let saved = PushStoredVariables.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, PushConstants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW-TOKEN")
        XCTAssertEqual(saved?.provider, PushConstants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_5: tokenUpdateCheck completes early when saved and current tokens are equal
    func test_5_tokenUpdateCheck_completesEarly_whenSavedAndCurrentTokensAreEqual() async {
        setSavedToken(
            provider: PushConstants.ProviderName.firebase,
            token: "SAME"
        )

        await setManualToken(
            provider: PushConstants.ProviderName.firebase,
            token: "SAME"
        )

        let result = await PushTokenProcess.shared.test_token_update_check(
            enableRetry: false
        )

        let current = await PushTokenProcess.shared.test_token_update_current_token()
        let saved = PushStoredVariables.shared.getSavedToken()

        XCTAssertTrue(result)
        XCTAssertNil(current)
        XCTAssertEqual(saved?.provider, PushConstants.ProviderName.firebase)
        XCTAssertEqual(saved?.token, "SAME")
    }

    /// test_6: tokenUpdate returns false and does not overwrite saved token when update request fails
    func test_6_tokenUpdate_returnsFalse_andDoesNotOverwriteSavedToken_whenUpdateRequestFails() async {
        setSavedToken(
            provider: PushConstants.ProviderName.apns,
            token: "OLD-TOKEN"
        )

        await setManualToken(
            provider: PushConstants.ProviderName.firebase,
            token: "NEW-TOKEN"
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await PushTokenProcess.shared.tokenUpdate(enableRetry: false)

        let current = await PushTokenProcess.shared.test_token_update_current_token()
        let saved = PushStoredVariables.shared.getSavedToken()

        XCTAssertFalse(result)
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.provider, PushConstants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW-TOKEN")
        XCTAssertEqual(saved?.provider, PushConstants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD-TOKEN")
    }

    /// test_7: tokenUpdateResult returns false on RetryEvent and does not save current token
    func test_7_tokenUpdateResult_returnsFalse_onRetryEvent_andDoesNotSaveCurrentToken() async {
        setSavedToken(
            provider: PushConstants.ProviderName.apns,
            token: "OLD"
        )

        await PushTokenProcess.shared.test_token_update_set_current_token(
            TokenData(
                provider: PushConstants.ProviderName.firebase,
                token: "NEW"
            )
        )

        await initSDK(apiUrl: "https://api.example.com", rToken: nil)

        let result = await PushTokenProcess.shared.test_token_update_result(
            enableRetry: false
        )

        let saved = PushStoredVariables.shared.getSavedToken()
        let current = await PushTokenProcess.shared.test_token_update_current_token()

        XCTAssertFalse(result)
        XCTAssertEqual(saved?.provider, PushConstants.ProviderName.apns)
        XCTAssertEqual(saved?.token, "OLD")
        XCTAssertEqual(current?.provider, PushConstants.ProviderName.firebase)
        XCTAssertEqual(current?.token, "NEW")
    }
}
