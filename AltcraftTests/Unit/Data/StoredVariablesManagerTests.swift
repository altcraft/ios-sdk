//
//  StoredVariablesManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * StoredVariablesManagerTests
 *
 * Positive scenarios:
 * - test_1: setCritDB and getDbErrorStatus store and retrieve true and false correctly.
 * - test_2: setGroupsName and getGroupName store and retrieve group string.
 * - test_3: setPushToken and getManualToken return expected token data.
 * - test_4: clearManualToken removes previously stored manual token.
 * - test_5: setCurrentToken and getSavedToken return expected token data.
 * - test_6: clearSavedToken removes previously stored saved token.
 * - test_7: TokenData JSON round-trip encodes and decodes identically.
 * - test_8: setPushToken with nil token clears manual token.
 * - test_9: setPushToken with empty token clears manual token.
 * - test_10: setCurrentToken with nil provider does nothing.
 * - test_11: setCurrentToken with empty provider does nothing.
 * - test_12: getGroupName handles nil case appropriately.
 *
 */
final class StoredVariablesManagerTests: IsolatedTestCase {

    private var sandbox: UserDefaultsSandbox!

    private let groupName = "AltcraftTests.TestGroup"
    private let providerFCM = "fcm"
    private let providerAPNs = "apns"
    private let token123 = "token123"
    private let tokenABC = "abc123"
    private let tokenXYZ = "xyz"
    private let tokenJSON = "test-token-123"

    private let msgEqual = "Values must be equal"
    private let msgNonNil = "Value must be non-nil"
    private let msgNil = "Value must be nil"

    private var standardKeysToClear: [String] {
        let prefix = Constants.UDPrefix
        return [
            "\(prefix)_CRIT_DB",
            "\(prefix)_GROUP_NAME",
            "\(prefix)_MANUAL_TOKEN",
            "\(prefix)_CURRENT_TOKEN",
            "\(prefix)_SAVED_TOKEN",
            "\(prefix)_LOGGING_STATUS"
        ]
    }

    private func clearStandardDefaults() {
        let defaults = UserDefaults.standard
        standardKeysToClear.forEach { defaults.removeObject(forKey: $0) }
        defaults.synchronize()
    }

    override func setUp() {
        super.setUp()
        sandbox = UserDefaultsSandbox()
        clearStandardDefaults()
        StoredVariablesManager.shared.setGroupsName(value: sandbox.suiteName)
    }

    override func tearDown() {
        clearStandardDefaults()
        sandbox.clear()
        sandbox = nil
        super.tearDown()
    }

    /// test_1: setCritDB and getDbErrorStatus store and retrieve true and false correctly
    func test_1_set_crit_db_and_get_db_error_status_store_and_retrieve_true_and_false_correctly() {
        StoredVariablesManager.shared.setCritDB(value: true)
        XCTAssertTrue(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)

        StoredVariablesManager.shared.setCritDB(value: false)
        XCTAssertFalse(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)
    }

    /// test_2: setGroupsName and getGroupName store and retrieve group string
    func test_2_set_groups_name_and_get_group_name_store_and_retrieve_group_string() {
        StoredVariablesManager.shared.setGroupsName(value: groupName)

        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertEqual(result, groupName, msgEqual)
    }

    /// test_3: setPushToken and getManualToken return expected token data
    func test_3_set_push_token_and_get_manual_token_return_expected_token_data() async {
        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: token123
        )

        let tokenData = await StoredVariablesManager.shared.getManualToken()

        XCTAssertNotNil(tokenData, msgNonNil)
        XCTAssertEqual(tokenData?.provider, providerFCM, msgEqual)
        XCTAssertEqual(tokenData?.token, token123, msgEqual)
    }

    /// test_4: clearManualToken removes previously stored manual token
    func test_4_clear_manual_token_removes_previously_stored_manual_token() async {
        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: token123
        )

        await StoredVariablesManager.shared.clearManualToken()

        let data = UserDefaults.standard.data(forKey: "\(Constants.UDPrefix)_MANUAL_TOKEN")
        XCTAssertNil(data, msgNil)
    }

    /// test_5: setCurrentToken and getSavedToken return expected token data
    func test_5_set_current_token_and_get_saved_token_return_expected_token_data() {
        StoredVariablesManager.shared.setCurrentToken(
            provider: providerAPNs,
            token: tokenABC
        )

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerAPNs, msgEqual)
        XCTAssertEqual(result?.token, tokenABC, msgEqual)
    }

    /// test_6: clearSavedToken removes previously stored saved token
    func test_6_clear_saved_token_removes_previously_stored_saved_token() {
        StoredVariablesManager.shared.setCurrentToken(
            provider: providerAPNs,
            token: tokenXYZ
        )

        StoredVariablesManager.shared.clearSavedToken()

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_7: TokenData JSON round-trip encodes and decodes identically
    func test_7_token_data_json_round_trip_encodes_and_decodes_identically() throws {
        let original = TokenData(provider: providerFCM, token: tokenJSON)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenData.self, from: data)

        XCTAssertEqual(decoded.provider, original.provider, msgEqual)
        XCTAssertEqual(decoded.token, original.token, msgEqual)
    }

    /// test_8: setPushToken with nil token clears manual token
    func test_8_set_push_token_with_nil_token_clears_manual_token() async {
        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: token123
        )

        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: nil
        )

        let data = UserDefaults.standard.data(forKey: "\(Constants.UDPrefix)_MANUAL_TOKEN")
        XCTAssertNil(data, msgNil)
    }

    /// test_9: setPushToken with empty token clears manual token
    func test_9_set_push_token_with_empty_token_clears_manual_token() async {
        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: token123
        )

        await StoredVariablesManager.shared.setPushToken(
            provider: providerFCM,
            token: ""
        )

        let data = UserDefaults.standard.data(forKey: "\(Constants.UDPrefix)_MANUAL_TOKEN")
        XCTAssertNil(data, msgNil)
    }

    /// test_10: setCurrentToken with nil provider does nothing
    func test_10_set_current_token_with_nil_provider_does_nothing() {
        StoredVariablesManager.shared.setCurrentToken(
            provider: nil,
            token: tokenABC
        )

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_11: setCurrentToken with empty provider does nothing
    func test_11_set_current_token_with_empty_provider_does_nothing() {
        StoredVariablesManager.shared.setCurrentToken(
            provider: "",
            token: tokenABC
        )

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_12: getGroupName handles nil case appropriately
    func test_12_get_group_name_handles_nil_case_appropriately() {
        StoredVariablesManager.shared.setGroupsName(value: nil)

        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertNil(result, msgNil)
    }
}
