//
//  TokenManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * TokenManagerTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_allProvidersValid_various_inputs
 *  - test_4_getCurrentToken_returns_manual_token_when_present
 *  - test_5_getCurrentToken_respects_priority_list_from_config
 *
 * Edge:
 *  - test_2_getAPNsTokenData_retries_and_succeeds_on_third_attempt
 *  - test_3_getFCM_and_HMS_token_when_provider_absent_returns_nil
 *
 * Notes:
 *  - Uses production Core Data stack to persist ConfigurationEntity.
 *  - Isolates UserDefaults by setting a temporary App Group.
 *  - Provider interfaces are stubbed in-tests to simulate tokens and retries.
 */
final class TokenManagerTests: XCTestCase {

    // MARK: - Test doubles

    /// Minimal APNS stub with scripted results per call.
    final class StubAPNS: APNSInterface {
        private var queue: [String?]
        init(results: [String?]) { self.queue = results }
        func getToken(completion: @escaping (String?) -> Void) {
            let next = queue.isEmpty ? nil : queue.removeFirst()
            completion(next)
        }
    }

    /// Minimal FCM stub.
    final class StubFCM: FCMInterface {
        private let token: String?
        private let deleteOK: Bool
        init(token: String?, deleteOK: Bool = true) { self.token = token; self.deleteOK = deleteOK }
        func getToken(completion: @escaping (String?) -> Void) { completion(token) }
        func deleteToken(completion: @escaping (Bool) -> Void) { completion(deleteOK) }
    }

    /// Minimal HMS stub.
    final class StubHMS: HMSInterface {
        private let token: String?
        private let deleteOK: Bool
        init(token: String?, deleteOK: Bool = true) { self.token = token; self.deleteOK = deleteOK }
        func getToken(completion: @escaping (String?) -> Void) { completion(token) }
        func deleteToken(completion: @escaping (Bool) -> Void) { completion(deleteOK) }
    }

    // MARK: - Constants / helpers

    private var originalGroup: String?
    private let providerAPNS = Constants.ProviderName.apns
    private let providerFCM  = Constants.ProviderName.firebase
    private let providerHMS  = Constants.ProviderName.huawei

    private func setTestAppGroup() {
        originalGroup = StoredVariablesManager.shared.getGroupName()
        StoredVariablesManager.shared.setGroupsName(value: "group.altcraft.tests.\(UUID().uuidString)")
    }

    private func restoreAppGroup() {
        StoredVariablesManager.shared.setGroupsName(value: originalGroup)
    }

    private func clearUserDefaultsTokens() {
        let u = StoredVariablesManager.shared
        u.clearManualToken()
        u.clearSavedToken()
    }

    /// Inserts/overwrites single ConfigurationEntity with providerPriorityList and minimal URL.
    private func seedConfig(priority: [String]) {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()
        ctx.performAndWait {
            // wipe existing
            let fr: NSFetchRequest<NSFetchRequestResult> = ConfigurationEntity.fetchRequest()
            let del = NSBatchDeleteRequest(fetchRequest: fr)
            _ = try? ctx.execute(del)

            // insert one
            let e = ConfigurationEntity(context: ctx)
            e.url = "https://api.altcraft.test/base"   // minimal valid
            e.rToken = "rt"
            e.appInfo = nil
            e.providerPriorityList = encodeProviderPriorityList(priority)
            try? ctx.save()
        }
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        setTestAppGroup()
        clearUserDefaultsTokens()

        // Reset shared TokenManager mutable state
        let tm = TokenManager.shared
        tm.apnsProvider = nil
        tm.fcmProvider = nil
        tm.hmsProvider = nil
        tm.tokens.removeAll()
    }

    override func tearDown() {
        // Reset again to be safe
        let tm = TokenManager.shared
        tm.apnsProvider = nil
        tm.fcmProvider = nil
        tm.hmsProvider = nil
        tm.tokens.removeAll()

        clearUserDefaultsTokens()
        restoreAppGroup()
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_allProvidersValid_various_inputs
    func test_1_allProvidersValid_current_behavior() {
          let tm = TokenManager.shared

          // nil -> false (per current implementation)
          XCTAssertFalse(tm.allProvidersValid(nil))

          // empty array -> true (allSatisfy on empty is true)
          XCTAssertTrue(tm.allProvidersValid([]))

          // known providers only -> true
          XCTAssertTrue(tm.allProvidersValid([Constants.ProviderName.apns]))
          XCTAssertTrue(tm.allProvidersValid([Constants.ProviderName.firebase, Constants.ProviderName.huawei]))

          // mix with unknown -> false
          XCTAssertFalse(tm.allProvidersValid(["unknown", Constants.ProviderName.apns]))

          // case-insensitive -> true
          XCTAssertTrue(tm.allProvidersValid([Constants.ProviderName.apns.uppercased()]))
      }

    /// test_2_getAPNsTokenData_retries_and_succeeds_on_third_attempt
    func test_2_getAPNsTokenData_retries_and_succeeds_on_third_attempt() {
        // First two attempts empty/nil, third returns valid token.
        TokenManager.shared.apnsProvider = StubAPNS(results: ["", nil, "APNS-TOK"])

        let exp = expectation(description: "apns token")
        var received: TokenData?
        TokenManager.shared.getAPNsTokenData { token in
            received = token
            exp.fulfill()
        }
        waitForExpectations(timeout: 5.0)

        XCTAssertNotNil(received)
        XCTAssertEqual(received?.provider, providerAPNS)
        XCTAssertEqual(received?.token, "APNS-TOK")
    }

    /// test_3_getFCM_and_HMS_token_when_provider_absent_returns_nil
    func test_3_getFCM_and_HMS_token_when_provider_absent_returns_nil() {
        // Providers not set => nils
        let exp1 = expectation(description: "fcm")
        TokenManager.shared.getFCMTokenData { tok in
            XCTAssertNil(tok)
            exp1.fulfill()
        }
        let exp2 = expectation(description: "hms")
        TokenManager.shared.getHMSTokenData { tok in
            XCTAssertNil(tok)
            exp2.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    /// test_4_getCurrentToken_returns_manual_token_when_present
    func test_4_getCurrentToken_returns_manual_token_when_present() {
        // Manual token short-circuits provider/config logic
        StoredVariablesManager.shared.setPushToken(provider: providerFCM, token: "MANUAL-123")

        let exp = expectation(description: "current token")
        var got: TokenData?
        TokenManager.shared.getCurrentToken { tok in
            got = tok
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        XCTAssertNotNil(got)
        XCTAssertEqual(got?.provider, providerFCM)
        XCTAssertEqual(got?.token, "MANUAL-123")
    }

    /// test_5_getCurrentToken_respects_priority_list_from_config
    func test_5_getCurrentToken_respects_priority_list_from_config() {
        // No manual token; configure providers + priority so that FCM is preferred over APNS.
        clearUserDefaultsTokens()
        seedConfig(priority: [providerFCM, providerAPNS, providerHMS])

        let tm = TokenManager.shared
        tm.fcmProvider  = StubFCM(token: "FCM-XYZ")
        tm.apnsProvider = StubAPNS(results: ["APNS-ABC"])  // valid but lower priority
        tm.hmsProvider  = StubHMS(token: nil)

        let exp = expectation(description: "ordered token selection")
        var got: TokenData?
        tm.getCurrentToken { tok in
            got = tok
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertNotNil(got)
        XCTAssertEqual(got?.provider, providerFCM)
        XCTAssertEqual(got?.token, "FCM-XYZ")
    }
}

