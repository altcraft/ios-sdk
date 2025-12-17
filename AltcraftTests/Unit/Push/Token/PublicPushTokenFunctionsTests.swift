//
//  PublicPushTokenFunctionsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PublicPushTokenFunctionsTests
 *
 * Positive scenarios:
 *  - test_1: Set FCM, HMS, APNS provider setters assign into token manager.
 *  - test_2: Set push token with string stores manual token and no error event.
 *  - test_3: Set push token with APNS data hex encodes and stores manual token.
 *  - test_4: Set push token with invalid provider emits error event.
 *  - test_5: Get push token returns manual token when present.
 *  - test_6: Change push provider priority list invalid emits error event.
 *  - test_7: Delete device token firebase calls provider delete and completion.
 *  - test_8: Delete device token huawei calls provider delete and completion.
 *  - test_9: Delete device token apns emits error event and completion called.
 *  - test_10: Delete device token invalid emits error event and completion called.
 */
final class PublicPushTokenFunctionsTests: XCTestCase {
    
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
        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    private func bestEffortClearManualToken() {
        let dummy = "DUMMY-\(UUID().uuidString)"
        StoredVariablesManager.shared.setPushToken(provider: Constants.ProviderName.firebase, token: dummy)
    }

    override func setUp() {
        super.setUp()
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil
        TokenManager.shared.apnsProvider = nil
        TokenManager.shared.tokens.removeAll()
        bestEffortClearManualToken()
    }

    override func tearDown() {
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil
        TokenManager.shared.apnsProvider = nil
        super.tearDown()
    }

    /// test_1: Set FCM, HMS, APNS provider setters assign into token manager
    func test_1_setFCM_HMS_APNS_Provider_setters_assignIntoTokenManager() {
        let fcm = MockFCM()
        let hms = MockHMS()
        let apns = MockAPNS()

        PublicPushTokenFunctions.shared.setFCMTokenProvider(fcm)
        PublicPushTokenFunctions.shared.setHMSTokenProvider(hms)
        PublicPushTokenFunctions.shared.setAPNSTokenProvider(apns)

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

        XCTAssertTrue(TokenManager.shared.fcmProvider is MockFCM)
        XCTAssertTrue(TokenManager.shared.hmsProvider is MockHMS)
        XCTAssertTrue(TokenManager.shared.apnsProvider is MockAPNS)
    }

    /// test_2: Set push token with string stores manual token and no error event
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

        let newEvents = Array(spy.events.dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (normalizeFunctionName($0.function) == "setPushToken")
        }
        XCTAssertFalse(hasSetPushTokenError, "No error expected for valid provider and String token")
    }

    /// test_3: Set push token with APNS data hex encodes and stores manual token
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

    /// test_4: Set push token with invalid provider emits error event
    func test_4_setPushToken_invalidProvider_emitsErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.setPushToken(provider: "__invalid__", pushToken: "t")

        XCTAssertTrue(spy.lastIsError(from: "setPushToken"))
        if let ev = spy.events.last as? ErrorEvent {
            XCTAssertEqual(normalizeFunctionName(ev.function), "setPushToken")
        }
    }

    /// test_5: Get push token returns manual token when present
    func test_5_getPushToken_returnsManualToken_whenPresent() {
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

    /// test_6: Change push provider priority list invalid emits error event
    func test_6_changePushProviderPriorityList_invalid_emitsErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.changePushProviderPriorityList(["__bad__", "ios-firebase"])

        XCTAssertTrue(spy.lastIsError(from: "changePushProviderPriorityList"))
        if let ev = spy.events.last as? ErrorEvent {
            XCTAssertEqual(normalizeFunctionName(ev.function), "changePushProviderPriorityList")
        }
    }

    /// test_7: Delete device token firebase calls provider delete and completion
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

    /// test_8: Delete device token huawei calls provider delete and completion
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

    /// test_9: Delete device token apns emits error event and completion called
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

    /// test_10: Delete device token invalid emits error event and completion called
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
