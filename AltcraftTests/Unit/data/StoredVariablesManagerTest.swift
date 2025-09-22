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
 *  - test_7: setSubRetryCount / getSubRetryCount return correct value.
 *  - test_8: setUpdateRetryCount / getUpdateRetryCount return correct value.
 *  - test_9: setPushEventRetryCount / getPushEventRetryCount return correct value.
 *  - test_10: TokenData JSON round-trip encodes/decodes identically.
 *
 * Edge scenarios:
 *  - test_11: getSubRetryCount returns default=1 when unset.
 *  - test_12: getUpdateRetryCount returns default=1 when unset.
 *  - test_13: getPushEventRetryCount returns nil when unset.
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

    private let retrySub     = 3
    private let retryUpdate  = 5
    private let retryPushEvt = 7

    private let defaultRetry = 1

    // ---------- Assertion messages ----------
    private let msgEqual   = "Values must be equal"
    private let msgNonNil  = "Value must be non-nil"
    private let msgNil     = "Value must be nil"

    // Keys we must reset in UserDefaults.standard to avoid cross-test leakage
    private let stdKeysToClear = [
        "CRIT_DB",
        "GROUP_NAME",
        "PUSH_SUB_LOC_RETRY",
        "TOKEN_UPDATE_LOC_RETRY",
        "PUSH_EVENT_LOC_RETRY"
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

    func test_1_setAndGetCritDBFlag() {
        StoredVariablesManager.shared.setCritDB(value: true)
        XCTAssertTrue(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)

        StoredVariablesManager.shared.setCritDB(value: false)
        XCTAssertFalse(StoredVariablesManager.shared.getDbErrorStatus(), msgEqual)
    }

    // MARK: - Group name

    func test_2_setAndGetGroupName() {
        StoredVariablesManager.shared.setGroupsName(value: groupName)
        let result = StoredVariablesManager.shared.getGroupName()
        XCTAssertEqual(result, groupName, msgEqual)
    }

    // MARK: - Manual token

    func test_3_setAndGetManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerFCM, msgEqual)
        XCTAssertEqual(result?.token, token123, msgEqual)
    }

    func test_4_clearManualToken() {
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: token123)
        StoredVariablesManager.shared.clearManualToken()

        let result = StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(result, msgNil)
    }

    // MARK: - Current/Saved token

    func test_5_setAndGetCurrentToken_asSaved() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenABC)

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(result, msgNonNil)
        XCTAssertEqual(result?.provider, providerAPNs, msgEqual)
        XCTAssertEqual(result?.token, tokenABC, msgEqual)
    }

    func test_6_clearSavedToken() {
        StoredVariablesManager.shared.setCurrentToken(provider: providerAPNs, token: tokenXYZ)
        StoredVariablesManager.shared.clearSavedToken()

        let result = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNil(result, msgNil)
    }

    // MARK: - Retry counters

    func test_7_subRetryCount_setAndGet() {
        StoredVariablesManager.shared.setSubRetryCount(value: retrySub)
        XCTAssertEqual(StoredVariablesManager.shared.getSubRetryCount(), retrySub, msgEqual)
    }

    func test_8_updateRetryCount_setAndGet() {
        StoredVariablesManager.shared.setUpdateRetryCount(value: retryUpdate)
        XCTAssertEqual(StoredVariablesManager.shared.getUpdateRetryCount(), retryUpdate, msgEqual)
    }

    func test_9_pushEventRetryCount_setAndGet() {
        StoredVariablesManager.shared.setPushEventRetryCount(value: retryPushEvt)
        XCTAssertEqual(StoredVariablesManager.shared.getPushEventRetryCount(), retryPushEvt, msgEqual)
    }

    // MARK: - Defaults (must be clean at start)

    func test_11_subRetryCount_defaultValue() {
        XCTAssertEqual(StoredVariablesManager.shared.getSubRetryCount(), defaultRetry, msgEqual)
    }

    func test_12_updateRetryCount_defaultValue() {
        XCTAssertEqual(StoredVariablesManager.shared.getUpdateRetryCount(), defaultRetry, msgEqual)
    }

    func test_13_pushEventRetryCount_defaultValue() {
        XCTAssertNil(StoredVariablesManager.shared.getPushEventRetryCount(), msgNil)
    }

    // MARK: - TokenData Codable roundtrip

    func test_10_tokenData_jsonRoundTrip_isStable() throws {
        let original = TokenData(provider: providerFCM, token: tokenJSON)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TokenData.self, from: data)

        XCTAssertEqual(decoded.provider, original.provider, msgEqual)
        XCTAssertEqual(decoded.token, original.token, msgEqual)
    }
}

