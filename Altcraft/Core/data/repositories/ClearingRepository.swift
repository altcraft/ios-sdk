//
//  ClearingRepository.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// A singleton class responsible for managing and clearing SDK Core Data entities.
actor ClearingRepository {

    /// The shared singleton instance of `ClearingRepository`.
    static let shared = ClearingRepository()

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
            CoreLog.error(#function, error: CoreEvents.invalidCoreDataEntityName)
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
                    CoreLog.error(#function, error: error)
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Deletes all core module entities (configuration, authentication,
    /// authentication requests) from the SDK Core Data store.
    ///
    /// Optional modules remove their own persisted data through their queue
    /// workers when ``ModuleRegistry/notifyClear()`` is dispatched.
    func deleteCoreEntities() async {
        let entities = [
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.authenticationEntity,
            Constants.EntityNames.authRequestEntity
        ]

        for entity in entities {
            _ = await deleteEntity(entityName: entity)
        }
    }
}
