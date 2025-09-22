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
///   - providerPriorityList: Sets the priority order of push notification providers.
///   - completion: Closure returning `true` on success, `false` on failure.
func setConfig(
    url: String,
    rToken: String?,
    appInfo: AppInfo?,
    providerPriorityList: [String]?,
    completion: @escaping (Bool) -> Void
) {
    guard !StoredVariablesManager.shared.getDbErrorStatus() else {
        errorEvent(#function, error: coreDataError)
        completion(false)
        return
    }

    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
    
        do {
            let existing = try context.fetch(fetchRequest).first
            if let storedToken = existing?.rToken {
                checkRTokenChange(context: context, rToken: rToken, existingRToken: storedToken)
            }

            let entity = existing ?? ConfigurationEntity(context: context)
            entity.url = url
            entity.rToken = rToken
            entity.appInfo = encodeAppInfo(appInfo)
            entity.providerPriorityList = encodeProviderPriorityList(providerPriorityList)

            try context.save()
            completion(true)

        } catch {
            errorEvent(#function, error: error)
            completion(false)
        }
    }
}

/// Checks if the `rToken` has changed and deletes all subscriptions if it did.
///
/// - Parameters:
///   - context: The Core Data context to perform the operation in.
///   - rToken: The new token.
///   - existingRToken: The token already stored in the configuration.
func checkRTokenChange(
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

        let fetch: NSFetchRequest<NSFetchRequestResult> = SubscribeEntity.fetchRequest()
        let delete = NSBatchDeleteRequest(fetchRequest: fetch)
        delete.resultType = .resultTypeObjectIDs

        if let result = try context.execute(delete) as? NSBatchDeleteResult,
           let deletedIDs = result.result as? [NSManagedObjectID] {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: deletedIDs],
                into: [context]
            )
        }

    } catch {
        errorEvent(#function, error: error)
    }
}

/// Retrieves a `Configuration` object from the Core Data store.
///
/// - Parameters:
///   - completion: A closure that is called with a `Configuration?`.
func getConfigFromCoreData(completion: @escaping (Configuration?) -> Void) {
    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
        do {
            if let configuration = try context.fetch(fetchRequest).first {
                completion(configFromEntity(configuration: configuration))
            } else {
                completion(nil)
            }
        } catch {
            errorEvent(#function, error: error)
            completion(nil)
        }
    }
}

/// Checks if a `ConfigurationEntity` with the specified resource token exists in the Core Data store.
///
/// - Parameters:
///   - resToken: The resource token to check for existence.
///   - completion: A closure that is called with a `Result<Bool, Error>`
///     indicating whether the entity exists or an error occurred during the fetch.
func doesConfigurationEntityExist(resToken: String, completion: @escaping (Result<Bool, Error>) -> Void) {
    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        context.perform {
            let fetchRequest: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            do {
                if let _ = try context.fetch(fetchRequest).first {
                    completion(.success(true))
                } else {
                    completion(.success(false))
                }
            } catch {
                errorEvent(#function, error: error)
                completion(.failure(error))
            }
        }
    }
}

/// Updates the `providerPriorityList` in Core Data and optionally executes a block with the context.
///
/// - Parameters:
///   - newList: The new list of provider priorities.
///   - onSaved: Optional closure executed with `context` after successful save.
func updateProviderPriorityList(
    newList: [String],
    onSaved: @escaping (Result<Void, Error>) -> Void
) {
    enum ConfigUpdateError: Error { case configIsNil }

    CoreDataManager.shared.persistentContainer.performBackgroundTask { context in
        let fetchRequest: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()

        do {
            guard let entity = try context.fetch(fetchRequest).first else {
                errorEvent(#function, error: configIsNil)
                onSaved(.failure(ConfigUpdateError.configIsNil))
                return
            }

            entity.providerPriorityList = encodeProviderPriorityList(newList)
            try context.save()

            onSaved(.success(()))
        } catch {
            errorEvent(#function, error: error)
            onSaved(.failure(error))
        }
    }
}



