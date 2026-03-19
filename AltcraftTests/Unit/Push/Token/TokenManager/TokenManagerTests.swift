//
//  TokenManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * TokenManagerTests
 *
 * Positive scenarios:
 *  - test_1: allProvidersValid → accepts supported providers and rejects invalid input.
 *  - test_2: getAPNsTokenData → retries until non-empty token is received.
 *  - test_3: getCurrentToken → fetches sequentially and stops on first successful provider.
 *  - test_4: getCurrentToken → uses manual token and emits a single token event for repeated value.
 *  - test_5: getCurrentToken → respects fallback provider order.
 *  - test_6: delete token methods → call provider delegates.
 *  - test_7: pushModuleIsActive → detects inactive and active states.
 *
 */
final class TokenManagerTests: IsolatedTestCase {

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

        func fresh(since count: Int) -> [Event] {
            lock.lock()
            defer { lock.unlock() }
            return Array(events.dropFirst(count))
        }

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return events.count
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

    private final class MockQueueProvider: APNSInterface, FCMInterface, HMSInterface {
        private var queue: [String?]
        var deleted = false

        init(tokensQueue: [String?]) {
            self.queue = tokensQueue
        }

        func getToken(completion: @escaping (String?) -> Void) {
            if queue.isEmpty {
                completion(nil)
                return
            }

            completion(queue.removeFirst())
        }

        func deleteToken(completion: @escaping (Bool) -> Void) {
            deleted = true
            completion(true)
        }
    }

    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw else { return "" }

        if let index = raw.firstIndex(of: "(") {
            return String(raw[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if raw.hasSuffix("()") {
            return String(raw.dropLast(2))
        }

        return raw
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        StoredVariablesManager.shared.setGroupsName(value: "AltcraftTests.TokenManager.\(UUID().uuidString)")
    }

    override func setUp() async throws {
        try await super.setUp()

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: nil
        )

        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)
    }

    override func tearDown() async throws {
        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: nil
        )

        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)

        try await super.tearDown()
    }

    /// test_1: allProvidersValid accepts supported providers and rejects invalid input
    func test_1_allProvidersValid_acceptsSupportedProviders_andRejectsInvalidInput() {
        let manager = TokenManager.shared

        let validCanonical = manager.allProvidersValid([
            Constants.ProviderName.apns,
            Constants.ProviderName.firebase,
            Constants.ProviderName.huawei
        ])

        let validMixedCase = manager.allProvidersValid([
            "ios-apns",
            "IOS-FIREBASE",
            "ios-huawei"
        ])

        let invalidNil = manager.allProvidersValid(nil)
        let invalidUnknown = manager.allProvidersValid([
            "unknown",
            Constants.ProviderName.apns
        ])

        XCTAssertTrue(validCanonical)
        XCTAssertTrue(validMixedCase)
        XCTAssertFalse(invalidNil)
        XCTAssertFalse(invalidUnknown)
    }

    /// test_2: getAPNsTokenData retries until non-empty token is received
    func test_2_getAPNsTokenData_retriesUntilNonEmptyToken_isReceived() async {
        let apns = MockQueueProvider(tokensQueue: [nil, "", "apns-token"])
        await TokenManager.shared.setAPNSProvider(apns)

        let start = Date()
        let token = await TokenManager.shared.getAPNsTokenData()

        XCTAssertEqual(token?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(token?.token, "apns-token")
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 2.0 - 0.2)
    }

    /// test_3: getCurrentToken fetches sequentially and stops on first successful provider
    func test_3_getCurrentToken_fetchesSequentially_andStopsOnFirstSuccessfulProvider() async {
        let hms = MockHMS()
        hms.tokenToReturn = "hms-token"

        await TokenManager.shared.setAPNSProvider(nil)
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(hms)

        let token = await TokenManager.shared.getCurrentToken()

        XCTAssertEqual(token?.provider, Constants.ProviderName.huawei)
        XCTAssertEqual(token?.token, "hms-token")
    }

    /// test_4: getCurrentToken uses manual token and emits a single token event for repeated value
    func test_4_getCurrentToken_usesManualToken_andEmitsSingleTokenEvent_forRepeatedValue() async {
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: "manual-1"
        )

        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count

        let token1 = await TokenManager.shared.getCurrentToken()
        XCTAssertEqual(token1?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(token1?.token, "manual-1")

        var firstEventCount = 0

        for _ in 0..<20 {
            let freshAfterFirst = spy.fresh(since: before)
            firstEventCount = freshAfterFirst.filter {
                normalizeFunctionName($0.function) == "tokenEvent"
            }.count

            if firstEventCount == 1 {
                break
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(firstEventCount, 1)

        let token2 = await TokenManager.shared.getCurrentToken()
        XCTAssertEqual(token2?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(token2?.token, "manual-1")

        var secondEventCount = 0

        for _ in 0..<20 {
            let freshAfterSecond = spy.fresh(since: before)
            secondEventCount = freshAfterSecond.filter {
                normalizeFunctionName($0.function) == "tokenEvent"
            }.count

            if secondEventCount == 1 {
                break
            }

            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(secondEventCount, 1)
    }

    /// test_5: getCurrentToken respects fallback provider order
    func test_5_getCurrentToken_respectsFallbackProviderOrder() async {
        let apns = MockQueueProvider(tokensQueue: [nil])
        let fcm = MockQueueProvider(tokensQueue: ["fcm-token"])
        let hms = MockQueueProvider(tokensQueue: ["hms-token"])

        await TokenManager.shared.setAPNSProvider(apns)
        await TokenManager.shared.setFCMProvider(fcm)
        await TokenManager.shared.setHMSProvider(hms)

        let token = await TokenManager.shared.getCurrentToken()

        XCTAssertEqual(token?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(token?.token, "fcm-token")
    }

    /// test_6: delete token methods call provider delegates
    func test_6_deleteTokenMethods_callProviderDelegates() async {
        let fcm = MockQueueProvider(tokensQueue: [])
        let hms = MockQueueProvider(tokensQueue: [])

        await TokenManager.shared.setFCMProvider(fcm)
        await TokenManager.shared.setHMSProvider(hms)

        let exp1 = expectation(description: "fcm delete")
        await TokenManager.shared.deleteFCMToken { ok in
            XCTAssertTrue(ok)
            exp1.fulfill()
        }

        let exp2 = expectation(description: "hms delete")
        await TokenManager.shared.deleteHMSToken { ok in
            XCTAssertTrue(ok)
            exp2.fulfill()
        }

        await fulfillment(of: [exp1, exp2], timeout: 1.0)
        XCTAssertTrue(fcm.deleted)
        XCTAssertTrue(hms.deleted)
    }

    /// test_7: pushModuleIsActive detects inactive and active states
    func test_7_pushModuleIsActive_detectsInactive_andActiveStates() async {
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: nil
        )

        let inactive = await TokenManager.shared.pushModuleIsActive()
        XCTAssertFalse(inactive)

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.apns,
            token: "x"
        )

        let active = await TokenManager.shared.pushModuleIsActive()
        XCTAssertTrue(active)
    }
}
