//
//  PublicPushTokenFunctionsTests.swift
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
 * PublicPushTokenFunctionsTests
 *
 * Positive scenarios:
 *  - test_1: provider setters → assign providers into token manager.
 *  - test_2: setPushToken with string → stores manual token and emits no error event.
 *  - test_3: setPushToken with APNS data → hex encodes and stores manual token.
 *  - test_4: setPushToken with invalid provider → emits error event.
 *  - test_5: getPushToken → returns manual token when present.
 *  - test_6: changePushPriorityList with invalid list → emits error event.
 *  - test_7: deleteDeviceToken firebase → calls provider delete and completion.
 *  - test_8: deleteDeviceToken huawei → calls provider delete and completion.
 *  - test_9: deleteDeviceToken apns → emits error event and calls completion.
 *  - test_10: deleteDeviceToken invalid → emits error event and calls completion.
 *
 */
final class PublicPushTokenFunctionsTests: IsolatedTestCase {

    /// Captures emitted SDK events.
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

        /// Pumps the main RunLoop until `lastIsError` matches or the deadline
        /// passes. SDK events emitted off the main thread are delivered via
        /// `RunLoop.main.perform`, so the pump must run on the main thread.
        func waitForError(from functionName: String, timeout: TimeInterval = 1.0) async {
            let deadline = Date().addingTimeInterval(timeout)
            await MainActor.run {
                while !lastIsError(from: functionName) && Date() < deadline {
                    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
                }
            }
        }

        private static func normalizeFunctionName(_ raw: String?) -> String {
            guard let raw else { return "" }
            var s = raw
            if let spaceIdx = s.firstIndex(of: " ") {
                let candidate = s[..<spaceIdx]
                if candidate.first == "[" && candidate.last == "]" {
                    s = String(s[s.index(after: spaceIdx)...])
                }
            }
            if let index = s.firstIndex(of: "(") {
                return String(s[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if s.hasSuffix("()") {
                return String(s.dropLast(2))
            }
            return s
        }
    }

    /// FCM provider mock.
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

    /// HMS provider mock.
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

    /// APNs provider mock.
    private final class MockAPNS: APNSInterface {
        var tokenToReturn: String?

        func getToken(completion: @escaping (String?) -> Void) {
            completion(tokenToReturn)
        }
    }

    private static func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw else { return "" }
        var s = raw
        if let spaceIdx = s.firstIndex(of: " ") {
            let candidate = s[..<spaceIdx]
            if candidate.first == "[" && candidate.last == "]" {
                s = String(s[s.index(after: spaceIdx)...])
            }
        }
        if let index = s.firstIndex(of: "(") {
            return String(s[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s.hasSuffix("()") {
            return String(s.dropLast(2))
        }
        return s
    }

    private func overwriteManualToken(provider: String, token: String) async {
        await PushStoredVariables.shared.setPushToken(
            provider: provider,
            token: token
        )
    }

    private func clearManualToken() async {
        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.firebase,
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

        TokenAPI.shared.setFCMTokenProvider(fcm)
        TokenAPI.shared.setHMSTokenProvider(hms)
        TokenAPI.shared.setAPNSTokenProvider(apns)

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

        TokenAPI.shared.setToken(
            provider: PushConstants.ProviderName.firebase,
            pushToken: "abc123"
        )

        let manual = await PushStoredVariables.shared.getManualToken()

        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, PushConstants.ProviderName.firebase)
        XCTAssertEqual(manual?.token, "abc123")

        let newEvents = Array(spy.snapshot().dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (Self.normalizeFunctionName($0.function) == "setToken")
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

        TokenAPI.shared.setToken(
            provider: PushConstants.ProviderName.apns,
            pushToken: data
        )

        let manual = await PushStoredVariables.shared.getManualToken()

        XCTAssertNotNil(manual)
        XCTAssertEqual(manual?.provider, PushConstants.ProviderName.apns)
        XCTAssertEqual(manual?.token.lowercased(), "deadbeef")

        let newEvents = Array(spy.snapshot().dropFirst(before))
        let hasSetPushTokenError = newEvents.contains {
            ($0 is ErrorEvent) && (Self.normalizeFunctionName($0.function) == "setToken")
        }

        XCTAssertFalse(hasSetPushTokenError)
    }

    /// test_4: setPushToken with invalid provider emits error event
    func test_4_setPushToken_withInvalidProvider_emitsErrorEvent() {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        TokenAPI.shared.setToken(
            provider: "__invalid__",
            pushToken: "t"
        )

        XCTAssertTrue(spy.lastIsError(from: "setToken"))

        if let event = spy.snapshot().last as? ErrorEvent {
            XCTAssertEqual(Self.normalizeFunctionName(event.function), "setToken")
        }
    }

    /// test_5: getPushToken returns manual token when present
    func test_5_getPushToken_returnsManualToken_whenPresent() async {
        await overwriteManualToken(
            provider: PushConstants.ProviderName.huawei,
            token: "MAN-777"
        )

        let exp = expectation(description: "getPushToken completion")

        TokenAPI.shared.getToken { tokenData in
            XCTAssertNotNil(tokenData)
            XCTAssertEqual(tokenData?.provider, PushConstants.ProviderName.huawei)
            XCTAssertEqual(tokenData?.token, "MAN-777")
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 2.0)
    }

    /// test_6: changePushPriorityList with invalid list emits error event
    func test_6_changePushPriorityList_withInvalidList_emitsErrorEvent() {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        TokenAPI.shared.changeProviderPriority([
            "__bad__",
            PushConstants.ProviderName.firebase
        ])

        XCTAssertTrue(spy.lastIsError(from: "changeProviderPriority"))

        if let event = spy.snapshot().last as? ErrorEvent {
            XCTAssertEqual(Self.normalizeFunctionName(event.function), "changeProviderPriority")
        }
    }

    /// test_7: deleteDeviceToken firebase calls provider delete and completion
    func test_7_deleteDeviceToken_firebase_callsProviderDelete_andCompletion() async {
        let fcm = MockFCM()
        await TokenManager.shared.setFCMProvider(fcm)

        let exp = expectation(description: "firebase delete completion")

        TokenAPI.shared.deleteToken(
            provider: PushConstants.ProviderName.firebase
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

        TokenAPI.shared.deleteToken(
            provider: PushConstants.ProviderName.huawei
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

        TokenAPI.shared.deleteToken(
            provider: PushConstants.ProviderName.apns
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        await spy.waitForError(from: "deleteToken")
        XCTAssertTrue(spy.lastIsError(from: "deleteToken"))
    }

    /// test_10: deleteDeviceToken invalid emits error event and calls completion
    func test_10_deleteDeviceToken_invalid_emitsErrorEvent_andCallsCompletion() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let exp = expectation(description: "invalid provider completion")

        TokenAPI.shared.deleteToken(
            provider: "__x__"
        ) {
            exp.fulfill()
        }

        await fulfillment(of: [exp], timeout: 1.0)
        await spy.waitForError(from: "deleteToken")
        XCTAssertTrue(spy.lastIsError(from: "deleteToken"))
    }
}
