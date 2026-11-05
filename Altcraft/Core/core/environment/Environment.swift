//
//  Environment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Provides lazily initialized environment for SDK operations:
/// configuration, user tag, authorization data, internal auth data, and push token.
///
/// Async accessors are cached and throw if required data is missing.
///
/// Core-only type. Other modules receive shared Core data through
/// `CoreEnvironmentProvider`.
final class Environment: @unchecked Sendable {

    private init() {}

    private let authLazy   = AsyncLazy<(header: String, matching: String)>()
    private let tagLazy    = AsyncLazy<String>()
    private let internalAuthLazy = AsyncLazy<InternalAuthData>()
    private let deviceFieldsLazy = AsyncLazy<DeviceFields>()

    /// Throws if Core Data is in critical error state.
    func checkCoreDataError() throws {
        if StoredVariablesManager.shared.getDbErrorStatus() {
            throw ExceptionExtension.exception(CoreEvents.coreDataError)
        }
    }

    /// Returns the SDK configuration; throws if configuration is missing.
    func config() async throws -> Configuration {
        guard let config = await ConfigManager.shared.getConfig() else {
            throw ExceptionExtension.exception(CoreEvents.configIsNil)
        }

        return config
    }

    /// Returns device metadata cached for this environment instance.
    ///
    /// Values are `_os`, `_os_tz`, `_os_language`, `_device_type`,
    /// `_device_model`, `_device_name`, `_os_ver`. Used by
    /// `MapBuilder.unionMaps` to enrich subscription custom fields.
    func deviceFields() async -> [String: Any] {
        let fields = (try? await deviceFieldsLazy.get {
            await MainActor.run {
                DeviceInfo.getDeviceFields()
            }
        }) ?? nil
        return fields?.asDictionary() ?? [:]
    }

    /// Returns the user tag; throws if tag is missing.
    func userTag() async throws -> String {
        let value = try await tagLazy.get {
            await getUserTag()
        }

        guard let value else {
            throw ExceptionExtension.exception(
                CoreEvents.userTagIsNil
            )
        }

        return value
    }

    /// Returns internal authorization data; throws if auth state is missing.
    func internalAuth() async throws -> InternalAuthData {
        let value = try await internalAuthLazy.get {
            try await self.loadInternalAuth()
        }

        guard let value else {
            throw ExceptionExtension.exception(
                CoreEvents.internalAuthDataIsNil
            )
        }

        return value
    }

    /// Returns authorization data (header and matching mode);
    /// throws if auth data is missing.
    func externalAuth() async throws -> (header: String, matching: String) {
        let value = try await authLazy.get { [self] in
            guard let pair = getAuthData(
                rToken: try await config().rToken
            ) else {
                return nil
            }

            return (header: pair.0, matching: pair.1)
        }

        guard let value else {
            throw ExceptionExtension.exception(
                CoreEvents.externalAuthDataIsNil
            )
        }

        return value
    }

    /// Clears cached values so they will be recomputed on next access.
    func resetCache() async {
        await ConfigManager.shared.clearCache()
        await authLazy.reset()
        await tagLazy.reset()
        await internalAuthLazy.reset()
    }

    /// Loads configuration from persistent storage.
    func loadConfig() async throws -> Configuration? {
        await ConfigManager.shared.getConfig()
    }

    /// Loads user tag from configuration/JWT.
    func loadTag() async throws -> String? {
        await getUserTag()
    }

    /// Loads internal auth data from Core Data.
    func loadInternalAuth() async throws -> InternalAuthData? {
        let context = CoreDataManager.shared.getContext()

        return await getInternalAuthData(context: context)
    }

    /// Builds authorization header and matching mode from configuration/JWT.
    func loadExternalAuth() async throws -> (header: String, matching: String)? {
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
