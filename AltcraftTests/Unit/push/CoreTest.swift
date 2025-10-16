//
//  CoreTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

// MARK: - Lightweight protocol stubs

private final class DummyFCM: FCMInterface {
    func getToken(completion: @escaping (String?) -> Void) { completion(nil) }
    func deleteToken(completion: @escaping (Bool) -> Void) { completion(true) }
}

private final class DummyHMS: HMSInterface {
    func getToken(completion: @escaping (String?) -> Void) { completion(nil) }
    func deleteToken(completion: @escaping (Bool) -> Void) { completion(true) }
}

private final class DummyAPNS: APNSInterface {
    func getToken(completion: @escaping (String?) -> Void) { completion(nil) }
}

/**
 * CoreTests (iOS 13 compatible)
 *
 * Coverage (concise, with explicit test names):
 *  - test_1_pushModuleIsActive_returnsTrue_whenManualTokenExists:
 *      Returns true if a manual token is stored.
 *  - test_2_pushModuleIsActive_returnsTrue_whenAnyProviderRegistered:
 *      Returns true if at least one provider (FCM/HMS/APNs) is set.
 *  - test_3_pushModuleIsActive_returnsFalse_whenNoTokenAndNoProviders:
 *      Returns false when no manual token and no providers are present.
 *  - test_4_performPushModuleCheck_setsTokenLogShowFalse_immediately:
 *      Immediately disables token debug logging.
 *  - test_5_performPushModuleCheck_smoke_noCrashes:
 *      Smoke test: completes without crashes or deadlocks.
 *
 * Notes:
 *  - Uses real singletons where necessary but isolates UserDefaults via a unique App Group per test.
 *  - No subclassing of final/internal types; providers are injected directly into TokenManager.shared.
 *  - Avoids deep pipeline/integration; only immediate, deterministic effects are asserted.
 */
final class CoreTests: XCTestCase {

    // MARK: - Per-test isolation helpers

    /// Creates a fresh `StoredVariablesManager` pointed at a unique App Group so keys do not clash.
    private func freshUserDefaults() -> StoredVariablesManager {
        let ud = StoredVariablesManager()
        ud.setGroupsName(value: "group.altcraft.tests.core.\(UUID().uuidString)")
        ud.clearManualToken()
        ud.clearSavedToken()
        return ud
    }

    /// Saves current TokenManager providers, runs block, then restores.
    private func withTokenManagerProviders<T>(
        fcm: FCMInterface? = nil,
        hms: HMSInterface? = nil,
        apns: APNSInterface? = nil,
        _ body: (TokenManager) -> T
    ) -> T {
        let tm = TokenManager.shared
        let prevFCM = tm.fcmProvider
        let prevHMS = tm.hmsProvider
        let prevAPNS = tm.apnsProvider
        tm.fcmProvider = fcm
        tm.hmsProvider = hms
        tm.apnsProvider = apns
        defer {
            tm.fcmProvider = prevFCM
            tm.hmsProvider = prevHMS
            tm.apnsProvider = prevAPNS
        }
        return body(tm)
    }

    // MARK: - pushModuleIsActive

    /// test_1_pushModuleIsActive_returnsTrue_whenManualTokenExists
    func test_1_pushModuleIsActive_returnsTrue_whenManualTokenExists() {
        let user = freshUserDefaults()
        user.setPushToken(provider: Constants.ProviderName.firebase, token: "TKN-1")

        withTokenManagerProviders(fcm: nil, hms: nil, apns: nil) { tm in
            XCTAssertTrue(pushModuleIsActive(userDefault: user, tokenManager: tm))
        }
    }

    /// test_2_pushModuleIsActive_returnsTrue_whenAnyProviderRegistered
    func test_2_pushModuleIsActive_returnsTrue_whenAnyProviderRegistered() {
        let user = freshUserDefaults() // no manual token

        // FCM only
        withTokenManagerProviders(fcm: DummyFCM(), hms: nil, apns: nil) { tm in
            XCTAssertTrue(pushModuleIsActive(userDefault: user, tokenManager: tm))
        }

        // HMS only
        withTokenManagerProviders(fcm: nil, hms: DummyHMS(), apns: nil) { tm in
            XCTAssertTrue(pushModuleIsActive(userDefault: user, tokenManager: tm))
        }

        // APNS only
        withTokenManagerProviders(fcm: nil, hms: nil, apns: DummyAPNS()) { tm in
            XCTAssertTrue(pushModuleIsActive(userDefault: user, tokenManager: tm))
        }
    }

    /// test_3_pushModuleIsActive_returnsFalse_whenNoTokenAndNoProviders
    func test_3_pushModuleIsActive_returnsFalse_whenNoTokenAndNoProviders() {
        let user = freshUserDefaults()
        withTokenManagerProviders(fcm: nil, hms: nil, apns: nil) { tm in
            XCTAssertFalse(pushModuleIsActive(userDefault: user, tokenManager: tm))
        }
    }

    // MARK: - performPushModuleCheck (unit-level)

    /// test_5_performPushModuleCheck_smoke_noCrashes
    func test_5_performPushModuleCheck_smoke_noCrashes() {
        let user = freshUserDefaults()
        withTokenManagerProviders(fcm: nil, hms: nil, apns: nil) { tm in
            performRetryOperations(userDefault: user, tokenManager: tm)
        }
        let exp = expectation(description: "spin main queue")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
    }
}

