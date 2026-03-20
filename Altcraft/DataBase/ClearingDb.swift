//
//  ClearingDb.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// A singleton class responsible for managing and clearing SDK Core Data entities.
actor ClearingDb {

    /// The shared singleton instance of `ClearingDb`.
    static let shared = ClearingDb()

    /// Deletes all entities of the specified type from the SDK Core Data store.
    ///
    /// This method performs the deletion of all instances of the specified entity type
    /// in the background using a `NSManagedObjectContext`.
    ///
    /// - Parameter entityName: The name of the entity to delete. This should match the entity name
    ///   defined in the Core Data model.
    /// - Returns: `true` if deletion completed successfully, otherwise `false`.
    func deleteEntity(entityName: String) async -> Bool {
        let container = CoreDataManager.shared.persistentContainer
        let model = container.managedObjectModel

        guard model.entitiesByName[entityName] != nil else {
            errorEvent(#function, error: invalidCoreDataEntityName)
            return false
        }

        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
                    entityName: entityName
                )
                fetchRequest.includesPropertyValues = false

                do {
                    let objects = try context.fetch(
                        fetchRequest
                    ) as? [NSManagedObject]

                    if let objects, !objects.isEmpty {
                        objects.forEach { context.delete($0) }
                    }

                    if context.hasChanges {
                        try context.save()
                    }

                    continuation.resume(returning: true)
                } catch {
                    errorEvent(#function, error: error)
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Deletes all entities of predefined types from the SDK Core Data store.
    ///
    /// - Returns: `true` if all delete operations were successful, otherwise `false`.
    func deleteAllEntitiesFromDb() async -> Bool {
        let entities = [
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.pushEventEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ]

        var overallSuccess = true

        for entity in entities {
            let success = await deleteEntity(entityName: entity)
            if !success {
                overallSuccess = false
            }
        }

        return overallSuccess
    }
}
