//
//  ConfigDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Saves or updates a configuration entity in the Core Data store.
///
/// Calls `checkRTokenChange` before updating to ensure subscription consistency.
///
/// - Parameters:
///   - url: The Altcraft API endpoint.
///   - rToken: The new resource token.
///   - appInfo: Additional app metadata.
///   - providerPriorityList: Priority order of push notification providers.
/// - Returns: `true` on success, `false` on failure.
func setConfig(
    url: String,
    rToken: String?,
    appInfo: AppInfo?,
    providerPriorityList: [String]?
) async -> Bool {
    guard !StoredVariablesManager.shared.getDbErrorStatus() else {
        errorEvent(#function, error: coreDataError)
        return false
    }

    let appInfoData = encodeAppInfo(appInfo)

    do {
        return try await CoreDataManager.shared.performBackgroundTask { context in
            do {
                let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
                
                let existingConfig = try context.fetch(req).first

                if let existingRToken = existingConfig?.rToken {
                    checkRTokenChange(
                        context: context,
                        rToken: rToken,
                        existingRToken: existingRToken
                    )
                }

                let entity = existingConfig ?? ConfigurationEntity(context: context)
                entity.url = url
                entity.rToken = rToken
                entity.appInfo = appInfoData
                entity.providerPriorityList = encodeProviderPriorityList(
                    providerPriorityList
                )

                if context.hasChanges {
                    try context.save()
                }

                return true
            } catch {
                errorEvent(#function, error: error)
                return false
            }
        }
    } catch {
        errorEvent(#function, error: error)
        return false
    }
}

/// Checks whether the `rToken` has changed.
/// If it has, deletes subscription, mobile event, and profile update entities.
///
/// - Parameters:
///   - context: The Core Data context to perform the operation in.
///   - rToken: The new token.
///   - existingRToken: The token already stored in the configuration.
private func checkRTokenChange(
    context: NSManagedObjectContext,
    rToken: String?,
    existingRToken: String?
) {
    do {
        guard let newToken = rToken,
              let oldToken = existingRToken,
              newToken != oldToken else {
            return
        }

        func batchDelete(_ fetch: NSFetchRequest<NSFetchRequestResult>) throws {
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            delete.resultType = .resultTypeObjectIDs

            if let result = try context.execute(delete) as? NSBatchDeleteResult,
               let deletedIDs = result.result as? [NSManagedObjectID],
               !deletedIDs.isEmpty {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
                    into: [context]
                )
            }
        }

        try batchDelete(SubscribeEntity.fetchRequest())
        try batchDelete(MobileEventEntity.fetchRequest())
        try batchDelete(ProfileUpdateEntity.fetchRequest())

    } catch {
        errorEvent(#function, error: error)
    }
}

/// Retrieves a `Configuration` object from the Core Data store.
///
/// - Returns: Configuration if present, otherwise `nil`.
func getConfig() async -> Configuration? {
    do {
        return try await CoreDataManager.shared.performBackgroundTask { context in
            do {
                let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
                
                guard let entity = try context.fetch(req).first else {
                    return nil
                }

                return configFromEntity(configuration: entity)
            } catch {
                errorEvent(#function, error: error)
                return nil
            }
        }
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Checks if a `ConfigurationEntity` exists in the Core Data store.
///
/// - Returns: `true` if any entity exists, otherwise `false`.
func doesConfigurationEntityExist() async -> Bool {
    do {
        return try await CoreDataManager.shared.performBackgroundTask { context in
            do {
                let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
                
                return try context.fetch(req).first != nil
            } catch {
                errorEvent(#function, error: error)
                return false
            }
        }
    } catch {
        errorEvent(#function, error: error)
        return false
    }
}

/// Updates the `providerPriorityList` in Core Data.
///
/// - Parameter newList: The new list of provider priorities.
/// - Returns: `true` on success, `false` on failure.
func updateProviderPriorityList(newList: [String]) async -> Bool {
    do {
        return try await CoreDataManager.shared.performBackgroundTask { context in
            do {
                let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()

                guard let config = try context.fetch(req).first else {
                    errorEvent(#function, error: configIsNil)
                    return false
                }

                config.providerPriorityList = encodeProviderPriorityList(newList)

                if context.hasChanges {
                    try context.save()
                }

                return true
            } catch {
                errorEvent(#function, error: error)
                return false
            }
        }
    } catch {
        errorEvent(#function, error: error)
        return false
    }
}
