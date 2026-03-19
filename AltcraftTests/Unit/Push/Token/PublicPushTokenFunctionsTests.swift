//
//  PublicPushTokenFunctionsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * PublicPushTokenFunctionsTests
 *
 * Positive scenarios:
 *  - test_1: provider setters → assign providers into token manager.
 *  - test_2: setPushToken with string → stores manual token and emits no error event.
 *  - test_3: setPushToken with APNS data → hex encodes and stores manual token.
 *  - test_4: setPushToken with invalid provider → emits error event.
 *  - test_5: getPushToken → returns manual token when present.
 *  - test_6: changePushProviderPriorityList with invalid list → emits error event.
 *  - test_7: deleteDeviceToken firebase → calls provider delete and completion.
 *  - test_8: deleteDeviceToken huawei → calls provider delete and completion.
 *  - test_9: deleteDeviceToken apns → emits error event and calls completion.
 *  - test_10: deleteDeviceToken invalid → emits error event and calls completion.
 *
 */
final class PublicPushTokenFunctionsTests: IsolatedTestCase {

    private final class EventSpy {
        private let lock = NSLock()
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] event in
                self?.lock.lock()
                self?.events.append(event)
                self?.lock.unlock()
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }

        func count() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return events.count
        }

        func snapshot() -> [Event] {
            lock.lock()
            defer { lock.unlock() }
            return events
        }

        func lastIsError(from functionName: String? = nil) -> Bool {
            lock.lock()
            defer { lock.unlock() }

            guard let last = events.last as? ErrorEvent else { return false }
            guard let functionName else { return true }
            return Self.normalizeFunctionName(last.function) == functionName
        }

        private static func normalizeFunctionName(_ raw: String?) -> String {
            guard let raw else { return "" }
            if let index = raw.firstIndex(of: "(") {
                return String(raw[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if raw.hasSuffix("()") {
                return String(raw.dropLast(2))
            }
            return raw
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
        guard let raw else { return "" }
        if let index = raw.firstIndex(of: "(") {
            return String(raw[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.hasSuffix("()") {
            return String(raw.dropLast(2))
        }
        return raw
    }

    private func overwriteManualToken(provider: String, token: String) async {
        await StoredVariablesManager.shared.setPushToken(
            provider: provider,
            token: token
        )
    }

    private func clearManualToken() async {
        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: nil
        )
    }

    override func setUp() async throws {
        try await super.setUp()
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)
        await TokenManager.shared.clearTokens()
        await clearManualToken()
    }

    override func tearDown() async throws {
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)
        await TokenManager.shared.clearTokens()
        await clearManualToken()
        try await super.tearDown()
    }

    /// test_1: provider setters assign providers into token manager
    func test_1_providerSetters_assignProvidersIntoTokenManager() async {
        let fcm = MockFCM()
        let hms = MockHMS()
        let apns = MockAPNS()

        PublicPushTokenFunctions.shared.setFCMTokenProvider(fcm)
        PublicPushTokenFunctions.shared.setHMSTokenProvider(hms)
        PublicPushTokenFunctions.shared.setAPNSTokenProvider(apns)

        try? await Task.sleep(nanoseconds: 100_000_000)

        let providers = await TokenManager.shared.test_getProviders()

        // Assert FCM
        if let provider = providers.fcm as? MockFCM {
            XCTAssertTrue(provider === fcm)
        } else {
            XCTFail("fcmProvider is not MockFCM")
        }

        // Assert HMS
        if let provider = providers.hms as? MockHMS {
            XCTAssertTrue(provider === hms)
        } else {
            XCTFail("hmsProvider is not MockHMS")
        }

        // Assert APNS
        if let provider = providers.apns as? MockAPNS {
            XCTAssertTrue(provider === apns)
        } else {
            XCTFail("apnsProvider is not MockAPNS")
        }

        // Type-level assertions
        XCTAssertTrue(providers.fcm is MockFCM)
        XCTAssertTrue(providers.hms is MockHMS)
        XCTAssertTrue(providers.apns is MockAPNS)
    }

    /// test_2: setPushToken with string stores manual token and emits no error event
    func test_2_setPushToken_withString_storesManualToken_andEmitsNoErrorEvent() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count()

        PublicPushTokenFunctions.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            pushToken: "abc123"
        )

        let manual = await StoredVariablesManager.shared.getManualToken()

        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(manual?.token, "abc123")

        let newEvents = Array(spy.snapshot().dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (Self.normalizeFunctionName($0.function) == "setPushToken")
        }

        XCTAssertFalse(hasSetPushTokenError)
    }

    /// test_3: setPushToken with APNS data hex encodes and stores manual token
    func test_3_setPushToken_withAPNSData_hexEncodes_andStoresManualToken() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count()
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])

        PublicPushTokenFunctions.shared.setPushToken(
            provider: Constants.ProviderName.apns,
            pushToken: data
        )

        let manual = await StoredVariablesManager.shared.getManualToken()

        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(manual?.token.lowercased(), "deadbeef")

        let newEvents = Array(spy.snapshot().dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (Self.normalizeFunctionName($0.function) == "setPushToken")
        }

        XCTAssertFalse(hasSetPushTokenError)
    }

    /// test_4: setPushToken with invalid provider emits error event
    func test_4_setPushToken_withInvalidProvider_emitsErrorEvent() {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.setPushToken(
            provider: "__invalid__",
            pushToken: "t"
        )

        XCTAssertTrue(spy.lastIsError(from: "setPushToken"))

        if let event = spy.snapshot().last as? ErrorEvent {
            XCTAssertEqual(Self.normalizeFunctionName(event.function), "setPushToken")
        }
    }

    /// test_5: getPushToken returns manual token when present
    func test_5_getPushToken_returnsManualToken_whenPresent() async {
        await overwriteManualToken(
            provider: Constants.ProviderName.huawei,
            token: "MAN-777"
        )

        let exp = expectation(description: "getPushToken completion")

        PublicPushTokenFunctions.shared.getPushToken { tokenData in
            XCTAssertNotNil(tokenData)
            XCTAssertEqual(tokenData?.provider, Constants.ProviderName.huawei)
            XCTAssertEqual(tokenData?.token, "MAN-777")
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 2.0)
    }

    /// test_6: changePushProviderPriorityList with invalid list emits error event
    func test_6_changePushProviderPriorityList_withInvalidList_emitsErrorEvent() {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        PublicPushTokenFunctions.shared.changePushProviderPriorityList([
            "__bad__",
            Constants.ProviderName.firebase
        ])

        XCTAssertTrue(spy.lastIsError(from: "changePushProviderPriorityList"))

        if let event = spy.snapshot().last as? ErrorEvent {
            XCTAssertEqual(Self.normalizeFunctionName(event.function), "changePushProviderPriorityList")
        }
    }

    /// test_7: deleteDeviceToken firebase calls provider delete and completion
    func test_7_deleteDeviceToken_firebase_callsProviderDelete_andCompletion() async {
        let fcm = MockFCM()
        await TokenManager.shared.setFCMProvider(fcm)

        let exp = expectation(description: "firebase delete completion")

        PublicPushTokenFunctions.shared.deleteDeviceToken(
            provider: Constants.ProviderName.firebase
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(fcm.deleted)
    }

    /// test_8: deleteDeviceToken huawei calls provider delete and completion
    func test_8_deleteDeviceToken_huawei_callsProviderDelete_andCompletion() async {
        let hms = MockHMS()
        await TokenManager.shared.setHMSProvider(hms)

        let exp = expectation(description: "huawei delete completion")

        PublicPushTokenFunctions.shared.deleteDeviceToken(
            provider: Constants.ProviderName.huawei
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(hms.deleted)
    }

    /// test_9: deleteDeviceToken apns emits error event and calls completion
    func test_9_deleteDeviceToken_apns_emitsErrorEvent_andCallsCompletion() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let exp = expectation(description: "apns branch completion")

        PublicPushTokenFunctions.shared.deleteDeviceToken(
            provider: Constants.ProviderName.apns
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(spy.lastIsError(from: "deleteDeviceToken"))
    }

    /// test_10: deleteDeviceToken invalid emits error event and calls completion
    func test_10_deleteDeviceToken_invalid_emitsErrorEvent_andCallsCompletion() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let exp = expectation(description: "invalid provider completion")

        PublicPushTokenFunctions.shared.deleteDeviceToken(
            provider: "__x__"
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        XCTAssertTrue(spy.lastIsError(from: "deleteDeviceToken"))
    }
}
