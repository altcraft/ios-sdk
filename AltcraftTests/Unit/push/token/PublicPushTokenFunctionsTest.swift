//
//  PublicPushTokenFunctionsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PublicPushTokenFunctionsTests (iOS 13 compatible)
 *
 * Coverage (concise, explicit test names):
 *  - test_1_setFCM_HMS_APNS_Provider_setters_assignIntoTokenManager
 *  - test_2_setPushToken_withString_storesManualToken_andNoErrorEvent
 *  - test_3_setPushToken_withAPNSData_hexEncodes_andStoresManualToken
 *  - test_4_setPushToken_invalidProvider_emitsErrorEvent
 *  - test_5_getPushToken_returnsManualToken_whenPresent
 *  - test_6_changePushProviderPriorityList_invalid_emitsErrorEvent
 *  - test_7_deleteDeviceToken_firebase_callsProviderDelete_andCompletion
 *  - test_8_deleteDeviceToken_huawei_callsProviderDelete_andCompletion
 *  - test_9_deleteDeviceToken_apns_emitsErrorEvent_andCompletionCalled
 *  - test_10_deleteDeviceToken_invalid_emitsErrorEvent_andCompletionCalled
 *
 * Notes:
 *  - Uses SDKEvents spy to assert ErrorEvent emissions.
 *  - Reads/writes manual token through StoredVariablesManager helpers that production code uses.
 *  - Does not rely on Core Data or network; all provider interactions are mocked.
 */
final class PublicPushTokenFunctionsTests: XCTestCase {

    // MARK: - Event Spy

    private final class EventSpy {
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] ev in
                self?.events.append(ev)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }

        func lastIsError(from functionName: String? = nil) -> Bool {
            guard let last = events.last as? ErrorEvent else { return false }
            guard let fn = functionName else { return true }
            return normalizeFunctionName(last.function) == fn
        }
    }

    // MARK: - Provider Mocks

    private final class MockFCM: FCMInterface {
        var tokenToReturn: String?
        var deleted = false

        func getToken(completion: @escaping (String?) -> Void) {
            completion(tokenToReturn)
        }
        func deleteToken(completion: @escaping (Bool) -> Void) {
            deleted = true
            completion(true)
        }
    }

    private final class MockHMS: HMSInterface {
        var tokenToReturn: String?
        var deleted = false

        func getToken(completion: @escaping (String?) -> Void) {
            completion(tokenToReturn)
        }
        func deleteToken(completion: @escaping (Bool) -> Void) {
            deleted = true
            completion(true)
        }
    }

    private final class MockAPNS: APNSInterface {
        var tokenToReturn: String?

        func getToken(completion: @escaping (String?) -> Void) {
            completion(tokenToReturn)
        }
    }

    // MARK: - Helpers

    private static func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") {
            return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.hasSuffix("()") { return String(raw.dropLast(2)) }
        return raw
    }
    private func normalizeFunctionName(_ raw: String?) -> String {
        Self.normalizeFunctionName(raw)
    }

    private func overwriteManualToken(provider: String, token: String) {
        // Store as manual token using the same helper production uses
        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    // Attempt to clear manual token (best-effort; if your StoredVariablesManager exposes explicit clear, prefer that).
    // Here we overwrite with another value per test where needed to avoid ambiguity.
    private func bestEffortClearManualToken() {
        // Overwrite with a short-lived dummy random token for a non-used provider, then overwrite back during a test.
        let dummy = "DUMMY-\(UUID().uuidString)"
        StoredVariablesManager.shared.setPushToken(provider: Constants.ProviderName.firebase, token: dummy)
    }

    override func setUp() {
        super.setUp()
        // Reset providers and attempt to neutralize prior manual token noise
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil
        TokenManager.shared.apnsProvider = nil
        TokenManager.shared.tokens.removeAll()
        bestEffortClearManualToken()
    }

    override func tearDown() {
        // Avoid cross-test coupling
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil
        TokenManager.shared.apnsProvider = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_setFCM_HMS_APNS_Provider_setters_assignIntoTokenManager
    func test_1_setFCM_HMS_APNS_Provider_setters_assignIntoTokenManager() {
        let fcm = MockFCM()
        let hms = MockHMS()
        let apns = MockAPNS()

        PublicPushTokenFunctions.shared.setFCMTokenProvider(fcm)
        PublicPushTokenFunctions.shared.setHMSTokenProvider(hms)
        PublicPushTokenFunctions.shared.setAPNSTokenProvider(apns)

        // Option A: identity check after downcast to concrete class
        if let prov = TokenManager.shared.fcmProvider as? MockFCM {
            XCTAssertTrue(prov === fcm)
        } else {
            XCTFail("fcmProvider is not MockFCM")
        }
        if let prov = TokenManager.shared.hmsProvider as? MockHMS {
            XCTAssertTrue(prov === hms)
        } else {
            XCTFail("hmsProvider is not MockHMS")
        }
        if let prov = TokenManager.shared.apnsProvider as? MockAPNS {
            XCTAssertTrue(prov === apns)
        } else {
            XCTFail("apnsProvider is not MockAPNS")
        }

        // Option B (alternative): just assert the types if identity is unnecessary
        XCTAssertTrue(TokenManager.shared.fcmProvider is MockFCM)
        XCTAssertTrue(TokenManager.shared.hmsProvider is MockHMS)
        XCTAssertTrue(TokenManager.shared.apnsProvider is MockAPNS)
    }

    /// test_2_setPushToken_withString_storesManualToken_andNoErrorEvent
    func test_2_setPushToken_withString_storesManualToken_andNoErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let before = spy.events.count

        PublicPushTokenFunctions.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            pushToken: "abc123"
        )

        let manual = StoredVariablesManager.shared.getManualToken()
        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(manual?.token, "abc123")

        // Проверяем только новые события, и только из setPushToken
        let newEvents = Array(spy.events.dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (normalizeFunctionName($0.function) == "setPushToken")
        }
        XCTAssertFalse(hasSetPushTokenError, "No error expected for valid provider and String token")
    }

    /// test_3_setPushToken_withAPNSData_hexEncodes_andStoresManualToken
    func test_3_setPushToken_withAPNSData_hexEncodes_andStoresManualToken() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let before = spy.events.count

        let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
        let data = Data(bytes)
        PublicPushTokenFunctions.shared.setPushToken(
            provider: Constants.ProviderName.apns,
            pushToken: data
        )

        let manual = StoredVariablesManager.shared.getManualToken()
        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(manual?.token.lowercased(), "deadbeef") 

        let newEvents = Array(spy.events.dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (normalizeFunctionName($0.function) == "setPushToken")
        }
        XCTAssertFalse(hasSetPushTokenError, "No error expected for valid APNs Data token")
    }


    /// test_4_setPushToken_invalidProvider_emitsErrorEvent
    func test_4_setPushToken_invalidProvider_emitsErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.setPushToken(provider: "__invalid__", pushToken: "t")

        XCTAssertTrue(spy.lastIsError(from: "setPushToken"))
        if let ev = spy.events.last as? ErrorEvent {
            XCTAssertEqual(normalizeFunctionName(ev.function), "setPushToken")
        }
    }

    /// test_5_getPushToken_returnsManualToken_whenPresent
    func test_5_getPushToken_returnsManualToken_whenPresent() {
        // Seed manual token first; TokenManager.getCurrentToken reads it before any provider logic.
        overwriteManualToken(provider: Constants.ProviderName.huawei, token: "MAN-777")

        let exp = expectation(description: "getPushToken completion")
        PublicPushTokenFunctions.shared.getPushToken { tokenData in
            XCTAssertNotNil(tokenData)
            XCTAssertEqual(tokenData?.provider, Constants.ProviderName.huawei)
            XCTAssertEqual(tokenData?.token, "MAN-777")
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    /// test_6_changePushProviderPriorityList_invalid_emitsErrorEvent
    func test_6_changePushProviderPriorityList_invalid_emitsErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.changePushProviderPriorityList(["__bad__", "ios-firebase"])

        XCTAssertTrue(spy.lastIsError(from: "changePushProviderPriorityList"))
        if let ev = spy.events.last as? ErrorEvent {
            XCTAssertEqual(normalizeFunctionName(ev.function), "changePushProviderPriorityList")
        }
    }

    /// test_7_deleteDeviceToken_firebase_callsProviderDelete_andCompletion
    func test_7_deleteDeviceToken_firebase_callsProviderDelete_andCompletion() {
        let fcm = MockFCM()
        TokenManager.shared.fcmProvider = fcm

        let done = expectation(description: "firebase delete completion")
        PublicPushTokenFunctions.shared.deleteDeviceToken(provider: Constants.ProviderName.firebase) {
            done.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(fcm.deleted, "FCM deleteToken must be called")
    }

    /// test_8_deleteDeviceToken_huawei_callsProviderDelete_andCompletion
    func test_8_deleteDeviceToken_huawei_callsProviderDelete_andCompletion() {
        let hms = MockHMS()
        TokenManager.shared.hmsProvider = hms

        let done = expectation(description: "huawei delete completion")
        PublicPushTokenFunctions.shared.deleteDeviceToken(provider: Constants.ProviderName.huawei) {
            done.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(hms.deleted, "HMS deleteToken must be called")
    }

    /// test_9_deleteDeviceToken_apns_emitsErrorEvent_andCompletionCalled
    func test_9_deleteDeviceToken_apns_emitsErrorEvent_andCompletionCalled() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let done = expectation(description: "apns branch completion")
        PublicPushTokenFunctions.shared.deleteDeviceToken(provider: Constants.ProviderName.apns) {
            done.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(spy.lastIsError(from: "deleteDeviceToken"))
    }

    /// test_10_deleteDeviceToken_invalid_emitsErrorEvent_andCompletionCalled
    func test_10_deleteDeviceToken_invalid_emitsErrorEvent_andCompletionCalled() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let done = expectation(description: "invalid provider completion")
        PublicPushTokenFunctions.shared.deleteDeviceToken(provider: "__x__") {
            done.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(spy.lastIsError(from: "deleteDeviceToken"))
    }
}

