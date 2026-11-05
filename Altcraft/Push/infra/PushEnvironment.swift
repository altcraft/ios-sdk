//
//  PushEnvironment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Provides dependencies required by the push module.
///
/// This is the single source of truth for module state: user tag, rToken mode,
/// push module configuration, and push tokens (manual, saved, current).
/// Shared Core data is requested through `CoreEnvironmentProvider`; tokens are
/// resolved within the push module itself.
struct PushEnvironment {

    /// Returns a freshly created push environment for an operation.
    ///
    /// Each call produces an independent (uncached) environment, matching the
    /// isolation expected by unit tests.
    static func fresh() -> PushEnvironment {
        PushEnvironment()
    }

    private init() {}

    /// Throws if the Core or Push module Core Data is in critical error state.
    ///
    /// The Push module's failure is isolated: it limits only push
    /// operations, the Core flag additionally covers Core's shared data.
    func checkCoreDataError() throws {
        try CoreEnvironmentProvider.checkDbError(
            module: PushConstants.CoreData.modelName
        )
    }

    /// Returns the current user tag.
    ///
    /// - Returns: Current user tag.
    func userTag() async throws -> String {
        try await CoreEnvironmentProvider.userTag()
    }

    /// Returns whether rToken-based authentication is in use.
    ///
    /// - Returns: `true` if the SDK configuration defines an rToken.
    func usesRTokenAuth() async throws -> Bool {
        try await CoreEnvironmentProvider.usesRToken()
    }

    /// Returns the push module configuration.
    ///
    /// - Returns: Current push configuration, or `nil` if it is not set.
    func pushConfig() async throws -> PushConfiguration? {
        await PushConfigManager.shared.getConfig()
    }

    /// Returns the manually assigned push token.
    ///
    /// - Returns: A manual push token, or `nil` if none exists.
    func manualToken() async -> TokenData? {
        await PushStoredVariables.shared.getManualToken()
    }

    /// Returns the previously saved push token.
    ///
    /// - Returns: A saved push token, or `nil` if none exists.
    func savedToken() -> TokenData? {
        PushStoredVariables.shared.getSavedToken()
    }

    /// Returns the current push token resolved from configured providers or the
    /// manually assigned token.
    ///
    /// - Returns: Current push token.
    func currentToken() async throws -> TokenData {
        guard let token = await TokenManager.shared.getCurrentToken()
        else {
            throw ExceptionExtension.exception(
                PushModuleEvents.pushTokenIsNil
            )
        }
        return token
    }
}
