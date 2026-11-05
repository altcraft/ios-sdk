//
//  CoreConfigDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import CoreData
import Foundation

/// Provides Core Data access for the SDK configuration.
final class CoreConfigDao: @unchecked Sendable {

    /// Saves or updates the SDK configuration.
    ///
    /// Role token change detection is owned by ``RTokenChange`` (Android
    /// parity, `RTokenChange.checkRTokenChangedFromInit`): the comparison
    /// against the previously saved token runs after the configuration is
    /// installed, so it also covers a role token extracted from a JWT.
    ///
    /// - Parameters:
    ///   - url: The Altcraft API endpoint.
    ///   - rToken: The new resource token.
    ///   - appInfo: Additional app metadata.
    /// - Returns: `true` on success, `false` on failure.
    func save(
        url: String,
        rToken: String?,
        appInfo: AppInfo?
    ) async -> Bool {
        do {
            try await saveConfiguration(
                url: url,
                rToken: rToken,
                appInfo: appInfo
            )

            return true

        } catch {
            CoreLog.error(#function, error: error)
            return false
        }
    }

    /// Fetches the stored SDK configuration.
    ///
    /// - Returns: The stored configuration, or `nil` when no configuration exists.
    func fetch() async -> Configuration? {
        do {
            return try await CoreDataManager.shared.performBackgroundTask { context in
                
                let request: NSFetchRequest<
                    ConfigurationEntity
                > = ConfigurationEntity.fetchRequest()

                request.fetchLimit = 1

                guard let entity = try context.fetch(request).first else {
                    return nil
                }

                return configFromEntity(
                    configuration: entity
                )
            }

        } catch {
            CoreLog.error(#function, error: error)
            return nil
        }
    }

    /// Checks whether an SDK configuration is stored.
    ///
    /// - Returns: `true` when a configuration exists, otherwise `false`.
    func exists() async -> Bool {
        do {
            return try await CoreDataManager.shared.performBackgroundTask { context in

                let request: NSFetchRequest<
                    ConfigurationEntity
                > = ConfigurationEntity.fetchRequest()

                request.fetchLimit = 1

                return try context.count(for: request) > 0
            }

        } catch {
            CoreLog.error(#function, error: error)
            return false
        }
    }

    /// Deletes all stored SDK configuration entities.
    ///
    /// Mirrors Android `ConfigurationDao.delete()`
    /// (`DELETE FROM configuration_table`).
    ///
    /// Delete errors are logged and swallowed inside the DAO.
    func delete() async {
        do {
            try await CoreDataManager.shared.performBackgroundTask { context in

                let request: NSFetchRequest<
                    ConfigurationEntity
                > = ConfigurationEntity.fetchRequest()

                request.includesPropertyValues = false

                for entity in try context.fetch(request) {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }

        } catch {
            CoreLog.error(#function, error: error)
        }
    }

    /// Persists the SDK configuration.
    ///
    /// - Parameters:
    ///   - url: The Altcraft API endpoint.
    ///   - rToken: The resource token to store.
    ///   - appInfo: Additional app metadata.
    private func saveConfiguration(
        url: String,
        rToken: String?,
        appInfo: AppInfo?
    ) async throws {
        let appInfoData = encodeAppInfo(appInfo)

        try await CoreDataManager.shared.performBackgroundTask { context in
            
            let request: NSFetchRequest<
                ConfigurationEntity
            > = ConfigurationEntity.fetchRequest()

            request.fetchLimit = 1

            let entity = try context.fetch(request).first
                ?? ConfigurationEntity(context: context)

            entity.url = url
            entity.rToken = rToken
            entity.appInfo = appInfoData

            if context.hasChanges {
                try context.save()
            }

        }
    }
}
