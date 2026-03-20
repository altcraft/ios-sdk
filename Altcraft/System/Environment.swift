//
//  Environment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Provides lazily initialized environment for SDK operations:
/// configuration, user tag, authorization data, and push token.
///
/// Async accessors are cached and throw if required data is missing.
internal final class Environment: @unchecked Sendable {

    private init() {}

    private let configLazy = AsyncLazy<Configuration>()
    private let tokenLazy  = AsyncLazy<TokenData>()
    private let authLazy   = AsyncLazy<(header: String, matching: String)>()
    private let tagLazy    = AsyncLazy<String>()

    /// Throws if Core Data is in critical error state.
    func checkCoreDataError() throws {
        if StoredVariablesManager.shared.getDbErrorStatus() {
            throw ExceptionExtension.exception(coreDataError)
        }
    }

    /// Returns the SDK configuration; throws if configuration is missing.
    func config() async throws -> Configuration {

        let value = try await configLazy.get {
            await getConfig()
        }

        guard let value else {
            throw ExceptionExtension.exception(configIsNil)
        }

        return value
    }

    /// Returns the current push token; throws if token is missing.
    func token() async throws -> TokenData {

        let value = try await tokenLazy.get {
            await TokenManager.shared.getCurrentToken()
        }

        guard let value else {
            throw ExceptionExtension.exception(pushTokenIsNil)
        }

        return value
    }

    /// Returns the user tag; throws if tag is missing.
    func userTag() async throws -> String {

        let value = try await tagLazy.get {
            await getUserTag()
        }

        guard let value else {
            throw ExceptionExtension.exception(userTagIsNil)
        }

        return value
    }

    /// Returns authorization data (header and matching mode); throws if auth data is missing.
    func auth() async throws -> (header: String, matching: String) {

        let value = try await authLazy.get { [self] in

            guard let pair = getAuthData(
                rToken: try await config().rToken
            ) else {
                return nil
            }

            return (header: pair.0, matching: pair.1)
        }

        guard let value else {
            throw ExceptionExtension.exception(authDataIsNil)
        }

        return value
    }

    /// Returns the last saved token from UserDefaults (if any).
    func savedToken() -> TokenData? {
        StoredVariablesManager.shared.getSavedToken()
    }

    /// Clears cached values so they will be recomputed on next access.
    ///
    /// Kept synchronous so existing call sites do not need to change.
    func resetCache() {

        let configLazy = self.configLazy
        let tokenLazy  = self.tokenLazy
        let authLazy   = self.authLazy
        let tagLazy    = self.tagLazy

        Task {
            await configLazy.reset()
            await tokenLazy.reset()
            await authLazy.reset()
            await tagLazy.reset()
        }
    }

    /// Loads configuration from persistent storage.
    func loadConfig() async throws -> Configuration? {
        await getConfig()
    }

    /// Loads current push token using configured provider priority.
    func loadToken() async throws -> TokenData? {
        await TokenManager.shared.getCurrentToken()
    }

    /// Loads user tag from configuration/JWT.
    func loadTag() async throws -> String? {
        await getUserTag()
    }

    /// Builds authorization header and matching mode from configuration/JWT.
    func loadAuth() async throws -> (header: String, matching: String)? {

        guard let pair = getAuthData(
            rToken: try await config().rToken
        ) else {
            return nil
        }

        return (header: pair.0, matching: pair.1)
    }

    /// Creates a new Environment instance.
    static func create() -> Environment {
        Environment()
    }
}
