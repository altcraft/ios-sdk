//
//  StoredVariablesManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * StoredVariablesManagerTests
 *
 * Positive scenarios:
 *  - test_1: setCritDB / getDbErrorStatus store and retrieve true/false correctly.
 *  - test_2: setGroupsName / getGroupName store and retrieve group string.
 *  - test_3: setPushToken + getManualToken return expected TokenData.
 *  - test_4: clearManualToken removes previously stored manual token.
 *  - test_5: setCurrentToken + getSavedToken return expected TokenData.
 *  - test_6: clearSavedToken removes previously stored saved token.
 *  - test_7: TokenData JSON round-trip encodes/decodes identically.
 *
 * Edge scenarios:
 *  - test_8: setPushToken with nil token clears manual token.
 *  - test_9: setPushToken with empty token clears manual token.
 *  - test_10: setCurrentToken with nil provider does nothing.
 *  - test_11: setCurrentToken with empty provider does nothing.
 *  - test_12: getGroupName logs error when group name is nil.
 */
final class StoredVariablesManagerTests: XCTestCase {

    private var sandbox: UserDefaultsSandbox!

    // ---------- Test constants ----------
    private let groupName    = "AltcraftTests.TestGroup"
    private let providerFCM  = "fcm"
    private let providerAPNs = "apns"
    private let token123     = "token123"
    private let tokenABC     = "abc123"
    private let tokenXYZ     = "xyz"
    private let tokenJSON    = "test-token-123"

    // ---------- Assertion messages ----------
    private let msgEqual   = "Values must be equal"
    private let msgNonNil  = "Value must be non-nil"
    private let msgNil     = "Value must be nil"

    // Keys we must reset in UserDefaults.standard to avoid cross-test leakage
    private let stdKeysToClear = [
        "CRIT_DB",
        "GROUP_NAME"
    ]

    private func clearStandardDefaults() {
        let std = UserDefaults.standard
        stdKeysToClear.forEach { std.removeObject(forKey: $0) }
        std.synchronize()
    }

    override func setUp() {
        super.setUp()
        // 1) Fresh isolated suite for suite-based storage
        sandbox = UserDefaultsSandbox()
        // 2) Ensure standard defaults are clean before every test
        clearStandardDefaults()
        // 3) Set group name after cleaning standard defaults
        UserDefaults.standard.set(sandbox.suiteName, forKey: "GROUP_NAME")
    }

    override func tearDown() {
        // Clean standard defaults again to avoid leakage to other test classes
        clearStandardDefaults()
        sandbox.clear()
        sandbox = nil
        super.tearDown()
    }

    // MARK: - Critical DB flag

    /// Critical DB flag stores and retrieves true/false correctly
    func test_1_setAndGetCritDBFlag() {
        StoredVariablesManager.shared.setCritDB(value: true)
        XCTAssertTrue(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)

        StoredVariablesManager.shared.setCritDB(value: false)
        XCTAssertFalse(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)
    }

    // MARK: - Group name

    /// Group name stores and retrieves string correctly
    func test_2_setAndGetGroupName() {
        StoredVariablesManager.shared.setGroupsName(value: groupName)
        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertEqual(result, groupName, msgEqual)
    }

    // MARK: - Manual token

    /// Manual token stores and retrieves TokenData correctly
    func test_3_setAndGetManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerFCM, msgEqual)
        XCTAssertEqual(result?.token, token123, msgEqual)
    }

    /// Clear manual token removes previously stored token
    func test_4_clearManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.clearManualToken()

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    /// Set push token with nil token clears manual token
    func test_8_setPushToken_withNilToken_clearsManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: nil)

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    /// Set push token with empty token clears manual token
    func test_9_setPushToken_withEmptyToken_clearsManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: "")

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    // MARK: - Current/Saved token

    /// Current token stores and retrieves as saved token correctly
    func test_5_setAndGetCurrentToken_asSaved() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerAPNs, msgEqual)
        XCTAssertEqual(result?.token, tokenABC, msgEqual)
    }

    /// Clear saved token removes previously stored token
    func test_6_clearSavedToken() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenXYZ)
        StoredVariablesManager.shared.clearSavedToken()

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// Set current token with nil provider does nothing
    func test_10_setCurrentToken_withNilProvider_doesNothing() {
        StoredVariablesManager.shared.setCurrentToken(provider: nil, token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    /// Set current token with empty provider does nothing
    func test_11_setCurrentToken_withEmptyProvider_doesNothing() {
        StoredVariablesManager.shared.setCurrentToken(provider: "", token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    // MARK: - Group name error handling

    /// Get group name handles nil case appropriately
    func test_12_getGroupName_handlesNilCase() {
        // Clear the group name first
        UserDefaults.standard.removeObject(forKey: "GROUP_NAME")
        
        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertNil(result, msgNil)
        // Note: The actual error logging would need to be verified separately
    }

    // MARK: - TokenData Codable roundtrip

    /// TokenData JSON round-trip encodes/decodes identically
    func test_7_tokenData_jsonRoundTrip_isStable() throws {
        let original = TokenData(provider: providerFCM, token: tokenJSON)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenData.self, from: data)

        XCTAssertEqual(decoded.provider, original.provider, msgEqual)
        XCTAssertEqual(decoded.token, original.token, msgEqual)
    }
}

