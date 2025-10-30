//
//  TokenManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * TokenManagerTests
 *
 * Coverage (concise, explicit test names):
 *  - test_1_allProvidersValid_variousInputs
 *  - test_2_sortProvidersByPriority_honorsPriorityAndCapsTo3
 *  - test_3_getNonEmptyToken_retriesUntilValue_thenStops
 *  - test_4_fetchTokensSequentially_stopsOnFirstSuccess
 *  - test_5_getCurrentToken_usesManualToken_and_emitsSingleEventPerNewToken
 *  - test_6_getCurrentToken_respectsPriorityList_and_fallbackOrder
 *  - test_7_deleteTokens_delegateCalled
 *  - test_8_pushModuleIsActive_detectsImmediateAndDelayedActivity_offMainThread
 */
final class TokenManagerTests: IsolatedTestCase {
    private func makeManager(
        fcm: FCMProviderLike? = nil,
        hms: HMSProviderLike? = nil,
        apns: APNSProviderLike? = nil,
        manualToken: TokenData? = nil,
        config: Configuration? = nil
    ) -> (TokenManager_Isolated, EventSink, TestStoredVariablesManager) {
        let sink = EventSink()
        let storage = TestStoredVariablesManager(defaults: defaults)
        storage.setManualToken(manualToken)
        let manager = TokenManager_Isolated(
            userDefaults: storage,
            eventSink: sink,
            getConfig: { completion in
                completion(config)
            }
        )
        manager.fcmProvider = fcm
        manager.hmsProvider = hms
        manager.apnsProvider = apns
        return (manager, sink, storage)
    }

    /// test_1_allProvidersValid_variousInputs
    func test_1_allProvidersValid_variousInputs() {
        let (m, _, _) = makeManager()
        XCTAssertTrue(m.allProvidersValid([Constants.ProviderName.apns, Constants.ProviderName.firebase, Constants.ProviderName.huawei]))
        XCTAssertTrue(m.allProvidersValid(["ios-apns", "ios-firebase", "ios-huawei"]))
        XCTAssertFalse(m.allProvidersValid(nil))
        XCTAssertFalse(m.allProvidersValid(["unknown", Constants.ProviderName.apns]))
    }

    /// test_2_sortProvidersByPriority_honorsPriorityAndCapsTo3
    func test_2_sortProvidersByPriority_honorsPriorityAndCapsTo3() {
        let (m, _, _) = makeManager()
        let providers: [(String, (@escaping (TokenData?) -> Void) -> Void)] = [
            (Constants.ProviderName.apns, { _ in }),
            (Constants.ProviderName.firebase, { _ in }),
            (Constants.ProviderName.huawei, { _ in })
        ]
        let p1 = m.sortProvidersByPriority(providers: providers, priorityList: [])
        XCTAssertEqual(p1.map { $0.type }, [Constants.ProviderName.apns, Constants.ProviderName.firebase, Constants.ProviderName.huawei])
        let p2 = m.sortProvidersByPriority(providers: providers, priorityList: [Constants.ProviderName.firebase, Constants.ProviderName.huawei, Constants.ProviderName.apns])
        XCTAssertEqual(p2.map { $0.type }, [Constants.ProviderName.firebase, Constants.ProviderName.huawei, Constants.ProviderName.apns])
        let p3 = m.sortProvidersByPriority(providers: providers, priorityList: [Constants.ProviderName.huawei])
        XCTAssertEqual(p3.map { $0.type }, [Constants.ProviderName.huawei])
    }

    /// test_3_getNonEmptyToken_retriesUntilValue_thenStops
    func test_3_getNonEmptyToken_retriesUntilValue_thenStops() {
        let (m, _, _) = makeManager(apns: MockAPNSProvider(tokensQueue: [nil, "", "apns-token"]))
        let exp = expectation(description: "apns token")
        let start = Date()
        m.getAPNsTokenData { token in
            XCTAssertEqual(token?.provider, Constants.ProviderName.apns)
            XCTAssertEqual(token?.token, "apns-token")
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 2.0 - 0.2)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3.5)
    }

    /// test_4_fetchTokensSequentially_stopsOnFirstSuccess
    func test_4_fetchTokensSequentially_stopsOnFirstSuccess() {
        let (m, _, _) = makeManager()
        let exp = expectation(description: "sequential fetch")
        let providers: [(String, (@escaping (TokenData?) -> Void) -> Void)] = [
            ("p1", { completion in completion(nil) }),
            ("p2", { completion in completion(nil) }),
            ("p3", { completion in completion(TokenData(provider: "p3", token: "t3")) })
        ]
        m.fetchTokensSequentially(providers: providers) { token in
            XCTAssertEqual(token?.provider, "p3")
            XCTAssertEqual(token?.token, "t3")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_5_getCurrentToken_usesManualToken_and_emitsSingleEventPerNewToken
    func test_5_getCurrentToken_usesManualToken_and_emitsSingleEventPerNewToken() {
        let manual = TokenData(provider: Constants.ProviderName.firebase, token: "manual-1")
        let (m, sink, _) = makeManager(
            manualToken: manual,
            config: Configuration(url: "", rToken: nil, appInfo: nil, providerPriorityList: nil)
        )
        let e1 = expectation(description: "first")
        m.getCurrentToken { token in
            XCTAssertEqual(token?.provider, manual.provider)
            XCTAssertEqual(token?.token, manual.token)
            e1.fulfill()
        }
        wait(for: [e1], timeout: 0.5)
        XCTAssertEqual(sink.events.count, 1)
        let e2 = expectation(description: "second")
        m.getCurrentToken { token in
            XCTAssertEqual(token?.provider, manual.provider)
            XCTAssertEqual(token?.token, manual.token)
            e2.fulfill()
        }
        wait(for: [e2], timeout: 0.5)
        XCTAssertEqual(sink.events.count, 1)
    }

    /// test_6_getCurrentToken_respectsPriorityList_and_fallbackOrder
    func test_6_getCurrentToken_respectsPriorityList_and_fallbackOrder() {
        let fcm = MockFCMProvider(tokensQueue: [nil, "fcm-token"])
        let apns = MockAPNSProvider(tokensQueue: [nil])
        let hms = MockHMSProvider(tokensQueue: ["hms-token"])
        let cfg1 = Configuration(url: "", rToken: nil, appInfo: nil, providerPriorityList: [Constants.ProviderName.huawei, Constants.ProviderName.firebase, Constants.ProviderName.apns])
        let (m1, _, _) = makeManager(fcm: fcm, hms: hms, apns: apns, config: cfg1)
        let e1 = expectation(description: "priority respects")
        m1.getCurrentToken { token in
            XCTAssertEqual(token?.provider, Constants.ProviderName.huawei)
            XCTAssertEqual(token?.token, "hms-token")
            e1.fulfill()
        }
        wait(for: [e1], timeout: 1.0)

        let fcm2 = MockFCMProvider(tokensQueue: ["fcm-token"])
        let cfg2 = Configuration(url: "", rToken: nil, appInfo: nil, providerPriorityList: [])
        let (m2, _, _) = makeManager(fcm: fcm2, hms: nil, apns: nil, config: cfg2)
        let e2 = expectation(description: "fallback order")
        m2.getCurrentToken { token in
            XCTAssertEqual(token?.provider, Constants.ProviderName.firebase)
            XCTAssertEqual(token?.token, "fcm-token")
            e2.fulfill()
        }
        wait(for: [e2], timeout: 1.0)
    }

    /// test_7_deleteTokens_delegateCalled
    func test_7_deleteTokens_delegateCalled() {
        let fcm = MockFCMProvider(tokensQueue: [])
        let hms = MockHMSProvider(tokensQueue: [])
        let (m, _, _) = makeManager(fcm: fcm, hms: hms)
        let e1 = expectation(description: "fcm delete")
        m.deleteFCMToken { ok in
            XCTAssertTrue(ok)
            e1.fulfill()
        }
        let e2 = expectation(description: "hms delete")
        m.deleteHMSToken { ok in
            XCTAssertTrue(ok)
            e2.fulfill()
        }
        wait(for: [e1, e2], timeout: 1.0)
        XCTAssertTrue(fcm.deleteCalled)
        XCTAssertTrue(hms.deleteCalled)
    }

    /// test_8_pushModuleIsActive_detectsImmediateAndDelayedActivity_offMainThread
    func test_8_pushModuleIsActive_detectsImmediateAndDelayedActivity_offMainThread() {
        let (m1, _, _) = makeManager(fcm: nil, hms: nil, apns: nil)
        let exp1 = expectation(description: "inactive after retries")
        let start = Date()
        m1.pushModuleIsActive { active in
            XCTAssertFalse(active)
            XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 2.0 - 0.2)
            XCTAssertFalse(Thread.isMainThread)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 3.5)

        let (m2, _, storage2) = makeManager(fcm: nil, hms: nil, apns: nil)
        let exp2 = expectation(description: "becomes active")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.1) {
            storage2.setManualToken(TokenData(provider: Constants.ProviderName.apns, token: "x"))
        }
        m2.pushModuleIsActive { active in
            XCTAssertTrue(active)
            XCTAssertFalse(Thread.isMainThread)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 3.5)
    }
}

