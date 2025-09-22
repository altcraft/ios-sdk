//
//  PushEventDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Creates and saves a new `PushEventEntity` into the Core Data context.
///
/// Initializes a new push event with the given `uid` and `type`, sets the timestamp and retry counters,
/// and saves it to Core Data. Returns the created entity if successful.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to create and save the entity.
///   - uid: The unique identifier of the push event.
///   - type: The type of the push event (e.g., "delivered", "opened").
///   - completion: A closure called with the created `PushEventEntity` or `nil` if saving failed.
func addPushEventEntity(
    context: NSManagedObjectContext,
    uid: String,
    type: String,
    completion: @escaping (PushEventEntity?) -> Void
) {
    do {
        let newEntity = PushEventEntity(context: context)
        newEntity.time = Int64(Date().timeIntervalSince1970)
        newEntity.uid = uid
        newEntity.type = type
        newEntity.retryCount = 0
        newEntity.maxRetryCount = 15

        try context.save()
        completion(newEntity)
    } catch {
        errorEvent(#function, error: error)
        completion(nil)
    }
}

/// Fetches all `PushEventEntity` objects from the Core Data context, sorted by time in ascending order.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the fetch.
///   - completion: A closure returning an array of `PushEventEntity` objects, or an empty array if fetch fails.
func getAllPushEvents(
    context: NSManagedObjectContext,
    completion: @escaping ([PushEventEntity]) -> Void
) {
    context.perform {
        let fetchRequest: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        
        do {
            let events = try context.fetch(fetchRequest)
            completion(events)
        } catch {
            errorEvent(#function, error: error)
            completion([])
        }
    }
}

/// Deletes the given `PushEventEntity` from the Core Data context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - entity: The `PushEventEntity` instance to delete.
///   - completion: A closure called with a `Bool` value indicating success (`true`) or failure (`false`).
func deletePushEvent(
    context: NSManagedObjectContext,
    entity: PushEventEntity,
    completion: ((Bool) -> Void)? = nil
) {
    context.perform {
        do {
            context.delete(entity)
            try context.save()
            completion?(true)
        } catch {
            errorEvent(#function, error: error)
            completion?(false)
        }
    }
}

/// Checks the retry limit for a given push event entity and updates its retry count if needed.
///
/// If `retryCount` < `maxRetryCount`, increments the count and saves the entity.
/// If `retryCount` ≥ `maxRetryCount`, deletes the entity.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` for database operations.
///   - entity: The `PushEventEntity` to process.
///   - completion: Closure with `true` if the entity was deleted, `false` if retry count was incremented.
func pushEventLimit(
    context: NSManagedObjectContext,
    for entity: PushEventEntity,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        let retryCount = Int(entity.retryCount)
        let maxRetryCount = Int(entity.maxRetryCount)
        
        if retryCount >= maxRetryCount {
            deletePushEvent(context: context, entity: entity) { _ in
                completion(true)
            }
        } else {
            entity.retryCount = Int16(retryCount + 1)
            do {
                try context.save()
                completion(false)
            } catch {
                errorEvent(#function, error: error)
                completion(false)
            }
        }
    }
}

/// Checks if the number of `PushEventEntity` records exceeds 500.
/// If so, deletes the 100 oldest entries based on the `time` field.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to fetch and delete records.
///   - completion: A closure called when the operation finishes, regardless of outcome.
func clearOldPushEvents(
    context: NSManagedObjectContext,
    completion: @escaping () -> Void
) {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PushEventEntity.fetchRequest()

    do {
        let totalCount = try context.count(for: fetchRequest)

        guard totalCount > 500 else {
            completion()
            return
        }

        let oldestFetch: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
        oldestFetch.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        oldestFetch.fetchLimit = 100

        let oldestRecords = try context.fetch(oldestFetch)

        for object in oldestRecords {
            context.delete(object)
        }

        try context.save()
        
    } catch {
        errorEvent(#function, error: error)
    }

    completion()
}
