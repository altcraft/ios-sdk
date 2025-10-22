//
//  PushEventDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Creates and saves a new `PushEventEntity` into the Core Data context, returning its `NSManagedObjectID`.
///
/// Initializes a new push event with the given `uid` and `type`, sets the timestamp and retry counters,
/// saves it to Core Data, and returns the created object's ID.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to create and save the entity.
///   - uid: The unique identifier of the push event.
///   - type: The type of the push event (e.g., "delivered", "opened").
///   - completion: A closure called with the created entity's `NSManagedObjectID` or `nil` if saving failed.
func addPushEventEntity(
    uid: String,
    type: String,
    completion: @escaping (NSManagedObjectID?) -> Void
) {
    withBackgroundContext{ context in
        let entity = PushEventEntity(context: context)
        entity.time = Int64(Date().timeIntervalSince1970 * 1000)
        entity.uid = uid
        entity.type = type
        entity.retryCount = 0
        entity.maxRetryCount = 15

        do {
            try context.save()
            completion(entity.objectID)
        } catch {
            errorEvent(#function, error: error)
            completion(nil)
        }
    }
}

/// Returns push event object IDs ordered by `time` ascending.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the fetch.
///   - completion: Callback with fetched object IDs (empty on failure).
func getAllPushEvents(
    context: NSManagedObjectContext,
    completion: @escaping ([NSManagedObjectID]) -> Void
) {
    context.perform {
        let request = NSFetchRequest<NSManagedObjectID>(
            entityName: Constants.EntityNames.pushEvent
        )
        request.resultType = .managedObjectIDResultType
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        do {
            let ids = try context.fetch(request)
            completion(ids)
        } catch {
            errorEvent(#function, error: error)
            completion([])
        }
    }
}

/// Deletes the `PushEventEntity` with the given object ID from Core Data.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - objectID: The `NSManagedObjectID` of the entity to delete.
///   - completion: A closure called with `true` on success (or if already gone / wrong type), `false` on failure.
func deletePushEvent(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: ((Bool) -> Void)? = nil
) {
    context.perform {
        guard
            let obj = try? context.existingObject(with: objectID),
                !obj.isDeleted
        else {
            completion?(true); return
        }
    
        context.delete(obj)
        
        do {
            if context.hasChanges {
                try context.save()
            }
            completion?(true)
        } catch {
            errorEvent(#function, error: error)
            completion?(false)
        }
    }
}

/// Checks the retry limit for a given push event (by object ID) and updates its retry count if needed.
///
/// If `retryCount` < `maxRetryCount`, increments the count and saves the entity.
/// If `retryCount` ≥ `maxRetryCount`, deletes the entity (or treats as deleted if missing/wrong type).
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` for database operations.
///   - objectID: `NSManagedObjectID` of `PushEventEntity` to process.
///   - completion: `true` if the entity was deleted (limit reached or missing/wrong type), `false` otherwise.
func pushEventLimit(
    context: NSManagedObjectContext,
    for objectID: NSManagedObjectID,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        guard let materialized = try? context.existingObject(with: objectID) else {
            completion(true)
            return
        }
        
        guard let entity = materialized as? PushEventEntity else {
            context.delete(materialized)
            do {
                try context.save()
            } catch {
                errorEvent(#function, error: error)
            }
            completion(true)
            return
        }

        let retryCount = Int(entity.retryCount)
        
        let maxRetryCount = Int(entity.maxRetryCount)

        if retryCount >= maxRetryCount {
            deletePushEvent(context: context, objectID: objectID) { _ in
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
