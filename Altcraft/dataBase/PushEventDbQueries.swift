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
        newEntity.time = Int64(Date().timeIntervalSince1970 * 1000)
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

import CoreData

/// Clears oldest `PushEventEntity` records when the total exceeds a threshold (mobile-like behavior).
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts (default: 500).
///   - purgeCount: Number of oldest records to delete when threshold is exceeded (default: 100).
///   - completion: Called when the operation finishes, regardless of outcome.
func clearOldPushEvents(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100,
    completion: @escaping () -> Void
) {
    context.perform {
        defer { completion() }

        do {
            // Count total records
            let countReq: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            // Fetch oldest N by time
            let fetchReq: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            fetchReq.fetchLimit = max(0, purgeCount)

            let oldest = try context.fetch(fetchReq)
            guard !oldest.isEmpty else { return }

            // Delete and persist
            oldest.forEach { context.delete($0) }
            try context.save()

        } catch {
            errorEvent(#function, error: error)
        }
    }
}
