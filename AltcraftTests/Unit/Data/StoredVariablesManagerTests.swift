//
//  StoredVariablesManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * StoredVariablesManagerTests
 *
 * Positive scenarios:
 *  - test_1: Set critical DB and get DB error status store and retrieve true/false correctly.
 *  - test_2: Set groups name and get group name store and retrieve group string.
 *  - test_3: Set push token and get manual token return expected token data.
 *  - test_4: Clear manual token removes previously stored manual token.
 *  - test_5: Set current token and get saved token return expected token data.
 *  - test_6: Clear saved token removes previously stored saved token.
 *  - test_7: Token data JSON round-trip encodes/decodes identically.
 *  - test_8: Set push token with nil token clears manual token.
 *  - test_9: Set push token with empty token clears manual token.
 *  - test_10: Set current token with nil provider does nothing.
 *  - test_11: Set current token with empty provider does nothing.
 *  - test_12: Get group name handles nil case appropriately.
 */
final class StoredVariablesManagerTests: IsolatedTestCase {

    private var sandbox: UserDefaultsSandbox!

    private let groupName    = "AltcraftTests.TestGroup"
    private let providerFCM  = "fcm"
    private let providerAPNs = "apns"
    private let token123     = "token123"
    private let tokenABC     = "abc123"
    private let tokenXYZ     = "xyz"
    private let tokenJSON    = "test-token-123"

    private let msgEqual   = "Values must be equal"
    private let msgNonNil  = "Value must be non-nil"
    private let msgNil     = "Value must be nil"

    private var stdKeysToClear: [String] {
        let prefix = Constants.UDPrefix
        return [
            "\(prefix)_CRIT_DB",
            "\(prefix)_GROUP_NAME",
            "\(prefix)_MANUAL_TOKEN",
            "\(prefix)_CURRENT_TOKEN"
        ]
    }

    private func clearStandardDefaults() {
        let std = UserDefaults.standard
        stdKeysToClear.forEach { std.removeObject(forKey: $0) }
        std.synchronize()
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

    /// test_1: Set critical DB and get DB error status store and retrieve true/false correctly
    func test_1_setAndGetCritDBFlag() {
        StoredVariablesManager.shared.setCritDB(value: true)
        XCTAssertTrue(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)

        StoredVariablesManager.shared.setCritDB(value: false)
        XCTAssertFalse(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)
    }

    /// test_2: Set groups name and get group name store and retrieve group string correctly
    func test_2_setAndGetGroupName() {
        StoredVariablesManager.shared.setGroupsName(value: groupName)
        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertEqual(result, groupName, msgEqual)
    }

    /// test_3: Set push token and get manual token return expected token data
    func test_3_setAndGetManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerFCM, msgEqual)
        XCTAssertEqual(result?.token, token123, msgEqual)
    }

    /// test_4: Clear manual token removes previously stored token
    func test_4_clearManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.clearManualToken()

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_5: Set current token and get saved token return expected token data
    func test_5_setAndGetCurrentToken_asSaved() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerAPNs, msgEqual)
        XCTAssertEqual(result?.token, tokenABC, msgEqual)
    }

    /// test_6: Clear saved token removes previously stored token
    func test_6_clearSavedToken() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenXYZ)
        StoredVariablesManager.shared.clearSavedToken()

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_7: Token data JSON round-trip encodes/decodes identically
    func test_7_tokenData_jsonRoundTrip_isStable() throws {
        let original = TokenData(provider: providerFCM, token: tokenJSON)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenData.self, from: data)

        XCTAssertEqual(decoded.provider, original.provider, msgEqual)
        XCTAssertEqual(decoded.token, original.token, msgEqual)
    }

    /// test_8: Set push token with nil token clears manual token
    func test_8_setPushToken_withNilToken_clearsManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: nil)

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_9: Set push token with empty token clears manual token
    func test_9_setPushToken_withEmptyToken_clearsManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: "")

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_10: Set current token with nil provider does nothing
    func test_10_setCurrentToken_withNilProvider_doesNothing() {
        StoredVariablesManager.shared.setCurrentToken(provider: nil, token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_11: Set current token with empty provider does nothing
    func test_11_setCurrentToken_withEmptyProvider_doesNothing() {
        StoredVariablesManager.shared.setCurrentToken(provider: "", token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// test_12: Get group name handles nil case appropriately
    func test_12_getGroupName_handlesNilCase() {
        StoredVariablesManager.shared.setGroupsName(value: nil)
        
        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertNil(result, msgNil)
    }
}

