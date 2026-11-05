//
//  TokenManagerTests.swift
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
 *  - test_8: resolvedPriority → normalizes case, drops unknown and duplicates.
 *
 */
final class TokenManagerTests: IsolatedTestCase {

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

    /// Composite provider mock for queue tests.
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
        guard let rawElse: String = raw else { return "" }
        var s = rawElse
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

    override func setUpWithError() throws {
        try super.setUpWithError()
        StoredVariablesManager.shared.setGroupsName(value: "AltcraftTests.TokenManager.\(UUID().uuidString)")
    }

    override func setUp() async throws {
        try await super.setUp()

        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.firebase,
            token: nil
        )

        await TokenManager.shared.clearTokens()
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)
    }

    override func tearDown() async throws {
        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.firebase,
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
            PushConstants.ProviderName.apns,
            PushConstants.ProviderName.firebase,
            PushConstants.ProviderName.huawei
        ])

        let validMixedCase = manager.allProvidersValid([
            "ios-apns",
            "IOS-FIREBASE",
            "ios-huawei"
        ])

        let invalidNil = manager.allProvidersValid(nil)
        let invalidUnknown = manager.allProvidersValid([
            "unknown",
            PushConstants.ProviderName.apns
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

        XCTAssertEqual(token?.provider, PushConstants.ProviderName.apns)
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

        XCTAssertEqual(token?.provider, PushConstants.ProviderName.huawei)
        XCTAssertEqual(token?.token, "hms-token")
    }

    /// test_4: getCurrentToken uses manual token and emits a single token event for repeated value
    func test_4_getCurrentToken_usesManualToken_andEmitsSingleTokenEvent_forRepeatedValue() async {
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)

        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.firebase,
            token: "manual-1"
        )

        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count

        let token1 = await TokenManager.shared.getCurrentToken()
        XCTAssertEqual(token1?.provider, PushConstants.ProviderName.firebase)
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
        XCTAssertEqual(token2?.provider, PushConstants.ProviderName.firebase)
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

        XCTAssertEqual(token?.provider, PushConstants.ProviderName.firebase)
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

        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.firebase,
            token: nil
        )

        let inactive = await TokenManager.shared.pushModuleIsActive()
        XCTAssertFalse(inactive)

        await PushStoredVariables.shared.setPushToken(
            provider: PushConstants.ProviderName.apns,
            token: "x"
        )

        let active = await TokenManager.shared.pushModuleIsActive()
        XCTAssertTrue(active)
    }

    /// test_8: resolvedPriority normalizes the configured priority list —
    /// case-insensitive matching against known providers, order preserved,
    /// unknown entries and duplicates dropped (mirrors the case-insensitive
    /// semantics of allProvidersValid).
    func test_8_resolvedPriority_normalizesCase_dropsUnknownAndDuplicates() {
        let resolved = TokenManager.shared.resolvedPriority([
            "IOS-APNS",
            "ios-apns",
            "bogus-provider",
            "IOS-FIREBASE",
            "ios-huawei"
        ])

        XCTAssertEqual(
            resolved,
            [
                PushConstants.ProviderName.apns,
                PushConstants.ProviderName.firebase,
                PushConstants.ProviderName.huawei
            ],
            "Priority must be canonical, ordered, and free of unknown/duplicate entries"
        )

        XCTAssertTrue(TokenManager.shared.resolvedPriority([]).isEmpty)
    }
}
