//
//  EnvironmentTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * EnvironmentTests
 *
 * Positive scenarios:
 * - test_1: checkCoreDataError does not throw when DB error flag is false.
 * - test_2: config returns stored configuration.
 * - test_3: token returns manual token when no push providers are installed.
 * - test_4: userTag returns rToken from configuration.
 * - test_5: auth returns Bearer header and matching from rToken.
 * - test_6: savedToken returns token stored in UserDefaults.
 * - test_7: loadConfig returns stored configuration without validation.
 * - test_8: loadToken returns manual token without validation.
 * - test_9: loadTag returns rToken from configuration.
 * - test_10: loadAuth returns Bearer header and matching from rToken.
 * - test_11: resetCache clears cached configuration and forces reload.
 *
 * Negative scenarios:
 * - test_12: checkCoreDataError throws when DB error flag is true.
 * - test_13: config throws when configuration is missing.
 * - test_14: token throws when token is missing.
 * - test_15: userTag throws when configuration is missing.
 * - test_16: auth throws when auth data is missing.
 * - test_17: loadConfig returns nil when configuration is missing.
 * - test_18: loadToken returns nil when token is missing.
 * - test_19: loadTag returns nil when configuration is missing.
 * - test_20: loadAuth returns nil when configuration exists but rToken is nil and JWT is unavailable.
 *
 */
final class EnvironmentTests: IsolatedTestCase {

    private func waitAsync(
        description: String = "async work",
        timeout: TimeInterval = 2.0,
        _ work: @escaping @Sendable () async -> Void
    ) {
        let exp = expectation(description: description)
        Task {
            await work()
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }

    private func waitAsyncThrowing<T: Sendable>(
        description: String = "async throwing work",
        timeout: TimeInterval = 2.0,
        _ work: @escaping @Sendable () async throws -> T
    ) throws -> T {
        let exp = expectation(description: description)

        var result: Result<T, Error>?

        Task {
            do {
                let value = try await work()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            exp.fulfill()
        }

        wait(for: [exp], timeout: timeout)

        let unwrapped = try XCTUnwrap(result, "Expected async work to produce a result")
        return try unwrapped.get()
    }

    private func wipeInMemory(_ entities: [String]) {
        for name in entities {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: name)
            if let objects = try? viewContext.fetch(req) as? [NSManagedObject] {
                objects.forEach { viewContext.delete($0) }
            }
        }

        if viewContext.hasChanges {
            try? viewContext.save()
        }
    }

    private func sdkWipe(_ entityNames: [String]) {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        let sema = DispatchSemaphore(value: 0)

        ctx.perform {
            for name in entityNames {
                let req = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                req.includesPropertyValues = false
                if let objects = try? ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach { ctx.delete($0) }
                }
            }

            if ctx.hasChanges {
                try? ctx.save()
            }

            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 5.0)
    }

    private func resetGlobalState() {
        StoredVariablesManager.shared.setCritDB(value: false)
        StoredVariablesManager.shared.clearSavedToken()

        waitAsync(description: "reset manual token") {
            await StoredVariablesManager.shared.clearManualToken()
        }

        waitAsync(description: "reset token manager providers") {
            await TokenManager.shared.setAPNSProvider(nil)
            await TokenManager.shared.setFCMProvider(nil)
            await TokenManager.shared.setHMSProvider(nil)
            await TokenManager.shared.clearTokens()
        }

        wipeInMemory([
            Constants.EntityNames.configurationEntity
        ])

        sdkWipe([
            Constants.EntityNames.configurationEntity
        ])
    }

    @discardableResult
    private func storeConfig(
        url: String = "https://api.altcraft.test",
        rToken: String? = "test-rtoken",
        providerPriorityList: [String]? = nil
    ) throws -> Bool {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        let sema = DispatchSemaphore(value: 0)

        var result: Result<Bool, Error>?

        ctx.perform {
            do {
                let req = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.configurationEntity)
                req.includesPropertyValues = false

                if let objects = try ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach { ctx.delete($0) }
                }

                let object = NSEntityDescription.insertNewObject(
                    forEntityName: Constants.EntityNames.configurationEntity,
                    into: ctx
                )

                object.setValue(url, forKey: "url")
                object.setValue(rToken, forKey: "rToken")

                if let providerPriorityList {
                    object.setValue(providerPriorityList, forKey: "providerPriorityList")
                }

                if ctx.hasChanges {
                    try ctx.save()
                }

                result = .success(true)
            } catch {
                result = .failure(error)
            }

            sema.signal()
        }

        _ = sema.wait(timeout: .now() + 5.0)

        let unwrapped = try XCTUnwrap(result, "Expected config store result")
        return try unwrapped.get()
    }

    private func storeManualToken(
        provider: String = Constants.ProviderName.apns,
        token: String = "MANUAL-TOKEN-1"
    ) {
        waitAsync(description: "store manual token") {
            await StoredVariablesManager.shared.setPushToken(
                provider: provider,
                token: token
            )
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        resetGlobalState()
    }

    override func tearDownWithError() throws {
        resetGlobalState()
        try super.tearDownWithError()
    }

    /// test_1: checkCoreDataError does not throw when DB error flag is false
    func test_1_checkCoreDataError_does_not_throw_when_db_error_flag_is_false() {
        StoredVariablesManager.shared.setCritDB(value: false)

        let environment = Environment.create()

        XCTAssertNoThrow(try environment.checkCoreDataError())
    }

    /// test_2: config returns stored configuration
    func test_2_config_returns_stored_configuration() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://env-config.altcraft.test",
            rToken: "env-config-token"
        ))

        let environment = Environment.create()
        let config = try await environment.config()

        XCTAssertEqual(config.url, "https://env-config.altcraft.test")
        XCTAssertEqual(config.rToken, "env-config-token")
    }

    /// test_3: token returns manual token when no push providers are installed
    func test_3_token_returns_manual_token_when_no_push_providers_are_installed() async throws {
        storeManualToken(
            provider: Constants.ProviderName.apns,
            token: "MANUAL-TOKEN-ENV"
        )

        let environment = Environment.create()
        let token = try await environment.token()

        XCTAssertEqual(token.provider, Constants.ProviderName.apns)
        XCTAssertEqual(token.token, "MANUAL-TOKEN-ENV")
    }

    /// test_4: userTag returns rToken from configuration
    func test_4_userTag_returns_rToken_from_configuration() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://tag.altcraft.test",
            rToken: "user-tag-rtoken"
        ))

        let environment = Environment.create()
        let userTag = try await environment.userTag()

        XCTAssertEqual(userTag, "user-tag-rtoken")
    }

    /// test_5: auth returns Bearer header and matching from rToken
    func test_5_auth_returns_bearer_header_and_matching_from_rToken() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://auth.altcraft.test",
            rToken: "auth-rtoken"
        ))

        let environment = Environment.create()
        let auth = try await environment.auth()

        XCTAssertEqual(auth.header, "Bearer rtoken@auth-rtoken")
        XCTAssertEqual(auth.matching, "auth-rtoken")
    }

    /// test_6: savedToken returns token stored in UserDefaults
    func test_6_savedToken_returns_token_stored_in_user_defaults() {
        StoredVariablesManager.shared.setCurrentToken(
            provider: Constants.ProviderName.firebase,
            token: "SAVED-TOKEN-1"
        )

        let environment = Environment.create()
        let token = environment.savedToken()

        XCTAssertEqual(token?.provider, Constants.ProviderName.firebase)
        XCTAssertEqual(token?.token, "SAVED-TOKEN-1")
    }

    /// test_7: loadConfig returns stored configuration without validation
    func test_7_loadConfig_returns_stored_configuration_without_validation() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://load-config.altcraft.test",
            rToken: "load-config-token"
        ))

        let environment = Environment.create()
        let config = try await environment.loadConfig()

        XCTAssertEqual(config?.url, "https://load-config.altcraft.test")
        XCTAssertEqual(config?.rToken, "load-config-token")
    }

    /// test_8: loadToken returns manual token without validation
    func test_8_loadToken_returns_manual_token_without_validation() async throws {
        storeManualToken(
            provider: Constants.ProviderName.huawei,
            token: "LOAD-TOKEN-1"
        )

        let environment = Environment.create()
        let token = try await environment.loadToken()

        XCTAssertEqual(token?.provider, Constants.ProviderName.huawei)
        XCTAssertEqual(token?.token, "LOAD-TOKEN-1")
    }

    /// test_9: loadTag returns rToken from configuration
    func test_9_loadTag_returns_rToken_from_configuration() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://load-tag.altcraft.test",
            rToken: "load-tag-token"
        ))

        let environment = Environment.create()
        let tag = try await environment.loadTag()

        XCTAssertEqual(tag, "load-tag-token")
    }

    /// test_10: loadAuth returns Bearer header and matching from rToken
    func test_10_loadAuth_returns_bearer_header_and_matching_from_rToken() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://load-auth.altcraft.test",
            rToken: "load-auth-token"
        ))

        let environment = Environment.create()
        let auth = try await environment.loadAuth()

        XCTAssertEqual(auth?.header, "Bearer rtoken@load-auth-token")
        XCTAssertEqual(auth?.matching, "load-auth-token")
    }

    /// test_11: resetCache clears cached configuration and forces reload
    func test_11_resetCache_clears_cached_configuration_and_forces_reload() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://before-reset.altcraft.test",
            rToken: "before-reset-token"
        ))

        let environment = Environment.create()
        let firstConfig = try await environment.config()

        XCTAssertEqual(firstConfig.url, "https://before-reset.altcraft.test")
        XCTAssertEqual(firstConfig.rToken, "before-reset-token")

        XCTAssertTrue(try storeConfig(
            url: "https://after-reset.altcraft.test",
            rToken: "after-reset-token"
        ))

        let cachedConfig = try await environment.config()
        XCTAssertEqual(cachedConfig.url, "https://before-reset.altcraft.test")
        XCTAssertEqual(cachedConfig.rToken, "before-reset-token")

        environment.resetCache()
        try? await Task.sleep(nanoseconds: 200_000_000)

        let reloadedConfig = try await environment.config()
        XCTAssertEqual(reloadedConfig.url, "https://after-reset.altcraft.test")
        XCTAssertEqual(reloadedConfig.rToken, "after-reset-token")
    }

    /// test_12: checkCoreDataError throws when DB error flag is true
    func test_12_checkCoreDataError_throws_when_db_error_flag_is_true() {
        StoredVariablesManager.shared.setCritDB(value: true)

        let environment = Environment.create()

        XCTAssertThrowsError(try environment.checkCoreDataError())
    }

    /// test_13: config throws when configuration is missing
    func test_13_config_throws_when_configuration_is_missing() async {
        let environment = Environment.create()

        do {
            _ = try await environment.config()
            XCTFail("Expected config() to throw when configuration is missing")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /// test_14: token throws when token is missing
    func test_14_token_throws_when_token_is_missing() async {
        let environment = Environment.create()

        do {
            _ = try await environment.token()
            XCTFail("Expected token() to throw when token is missing")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /// test_15: userTag throws when configuration is missing
    func test_15_userTag_throws_when_configuration_is_missing() async {
        let environment = Environment.create()

        do {
            _ = try await environment.userTag()
            XCTFail("Expected userTag() to throw when configuration is missing")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /// test_16: auth throws when auth data is missing
    func test_16_auth_throws_when_auth_data_is_missing() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://missing-auth.altcraft.test",
            rToken: nil
        ))

        let environment = Environment.create()

        do {
            _ = try await environment.auth()
            XCTFail("Expected auth() to throw when auth data is missing")
        } catch {
            XCTAssertTrue(true)
        }
    }

    /// test_17: loadConfig returns nil when configuration is missing
    func test_17_loadConfig_returns_nil_when_configuration_is_missing() async throws {
        let environment = Environment.create()
        let config = try await environment.loadConfig()

        XCTAssertNil(config)
    }

    /// test_18: loadToken returns nil when token is missing
    func test_18_loadToken_returns_nil_when_token_is_missing() async throws {
        let environment = Environment.create()
        let token = try await environment.loadToken()

        XCTAssertNil(token)
    }

    /// test_19: loadTag returns nil when configuration is missing
    func test_19_loadTag_returns_nil_when_configuration_is_missing() async throws {
        let environment = Environment.create()
        let tag = try await environment.loadTag()

        XCTAssertNil(tag)
    }

    /// test_20: loadAuth returns nil when configuration exists but rToken is nil and JWT is unavailable
    func test_20_loadAuth_returns_nil_when_configuration_exists_but_rToken_is_nil_and_jwt_is_unavailable() async throws {
        XCTAssertTrue(try storeConfig(
            url: "https://nil-auth.altcraft.test",
            rToken: nil
        ))

        let environment = Environment.create()
        let auth = try await environment.loadAuth()

        XCTAssertNil(auth)
    }
}
