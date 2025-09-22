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
class ClearingDb: NSObject {

    /// The shared singleton instance of `ClearingDb`.
    static let shared = ClearingDb()

    /// Deletes all entities of the specified type from the SDK Core Data store.
    ///
    /// This method performs the deletion of all instances of the specified entity type
    /// in the background using a `NSManagedObjectContext`. It fetches the entities, deletes
    /// them, and saves the context. The completion handler is called with a `Bool` indicating
    /// whether the operation was successful.
    ///
    /// - Parameter entityName: The name of the entity to delete. This should match the entity name
    ///   defined in the Core Data model.
    /// - Parameter completion: A closure to be called once the operation is complete. The closure
    ///   takes a `Bool` parameter indicating whether the deletion was successful.
    func deleteEntity(entityName: String, completion: @escaping (Bool) -> Void) {
        let container = CoreDataManager.shared.persistentContainer

        let model = container.managedObjectModel
        guard model.entitiesByName[entityName] != nil else {
            errorEvent(#function, error: invalidCoreDataEntityName)
            DispatchQueue.main.async { completion(false) }
            return
        }

        container.performBackgroundTask { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.includesPropertyValues = false
            do {
                let objects = try context.fetch(fetchRequest) as? [NSManagedObject]
                if let objects = objects, !objects.isEmpty {
                    objects.forEach { context.delete($0) }
                }
                if context.hasChanges {
                    try context.save()
                }
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                errorEvent(#function, error: error)
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    /// Deletes all entities of predefined types from the SDK Core Data store.
    ///
    /// This method calls `deleteAllEntities(entityName:completion:)` for each predefined entity type
    /// and aggregates the success of each operation. The completion handler is called with a `Bool`
    /// indicating whether all delete operations were successful.
    ///
    /// - Parameter completion: A closure to be called once all delete operations are complete. The closure
    ///   takes a `Bool` parameter indicating whether all deletions were successful.
    func deleteAllEntitiesFromDb(completion: @escaping (Bool) -> Void) {
        let group = DispatchGroup()
        var overallSuccess = true
        [
            Constants.EntityNames.configEntityName,
            Constants.EntityNames.subscribeEntityName,
            Constants.EntityNames.pushEventEntityName
        ].forEach { entityName in
            group.enter()
            deleteEntity(entityName: entityName) { success in
                if !success {
                    overallSuccess = false
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(overallSuccess)
        }
    }
}


