//
//  SubscribeDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Adds a new entry to the `SubscribeEntity` table.
///
/// Stores subscription event data in Core Data.
/// Entries are ordered by `time` so the oldest appear first.
///
/// - Parameters:
///   - userTag: User tag string.
///   - status: Subscription status string.
///   - sync: Sync mode (integer).
///   - profileFields: Optional profile fields to serialize and store.
///   - customFields: Optional custom fields to serialize and store.
///   - cats: Optional list of categories to store.
///   - replace: Whether this entry should replace existing one.
///   - skipTriggers: Whether triggers should be skipped.
///   - uid: Request identifier.
///   - completion: Completion handler returning `Result<Void, Error>`.
///                 Use `.success(())` when the entity is saved successfully,
///                 or `.failure(error)` if save fails.
func addSubscribeEntity(
    userTag: String,
    status: String,
    sync: Int,
    profileFields: [String: Any?]?,
    customFields: [String: Any?]?,
    cats: [CategoryData]?,
    replace: Bool?,
    skipTriggers: Bool?,
    uid: String?,
    completion: @escaping (Result<Void, Error>) -> Void
) {
    withBackgroundContext { context in
        do {
            let newEntity = SubscribeEntity(context: context)
            newEntity.time = Int64(Date().timeIntervalSince1970 * 1000)
            newEntity.uid = uid
            newEntity.userTag = userTag
            newEntity.status = status
            newEntity.sync = Int16(sync)
            newEntity.replace = replace ?? false
            newEntity.skipTriggers = skipTriggers ?? false
            newEntity.cats = encodeCats(cats)
            newEntity.profileFields = encodeAnyMap(profileFields)
            newEntity.customFields = encodeAnyMap(customFields)
            newEntity.retryCount = 0
            newEntity.maxRetryCount = 15

            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}

/// Fetches object IDs of all `SubscribeEntity` rows where `userTag` matches.
/// Returns `NSManagedObjectID` to avoid leaking managed objects across queues.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used for Core Data operations.
///   - userTag: Tag used to filter subscriptions.
///   - completion: Closure returning an array of `NSManagedObjectID`.
func getAllSubscriptionsByTag(
    context: NSManagedObjectContext,
    userTag: String,
    completion: @escaping ([NSManagedObjectID]) -> Void
) {
    context.perform {
        let request = NSFetchRequest<NSManagedObjectID>(
            entityName: Constants.EntityNames.subscribe
        )
        request.resultType = .managedObjectIDResultType
        request.predicate = NSPredicate(format: "userTag == %@", userTag)
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

/// Deletes the `SubscribeEntity` with the given object ID from Core Data.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - objectID: The `NSManagedObjectID` of the entity to delete.
///   - completion: Called with `true` on success (or if already gone), `false` on failure.
///
/// - Note: Runs on the context's queue via `perform`.
func deleteSubscriptions(
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

/// Checks the retry limit for a given subscription entity and updates its retry count if needed.
///
/// Compares `retryCount` with `maxRetryCount`.
/// If the retry count is below the limit, increments it and saves the entity.
/// If it equals or exceeds the limit, deletes the entity.
/// If the entity cannot be materialized by its `NSManagedObjectID` (already deleted/missing),
/// or the materialized object is not a `SubscribeEntity`, it is deleted/treated as deleted.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to update or delete the subscription entity.
///   - objectID: The `NSManagedObjectID` of the `SubscribeEntity` to check and update.
///   - completion: A closure called with `true` if the entity was deleted (or not found / wrong type),
///                 or `false` if it was updated (retry count incremented) or saving failed.
///
/// - Note: If the retry limit is exceeded (or entity is missing / wrong type), the entity is deleted/treated as deleted and `true` is returned.
///         If the count is incremented and saved, `false` is returned.
func subscribeLimit(
    context: NSManagedObjectContext,
    for objectID: NSManagedObjectID,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        guard let materialized = try? context.existingObject(with: objectID) else {
            completion(true)
            return
        }
        
        guard let entity = materialized as? SubscribeEntity else {
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
            deleteSubscriptions(context: context, objectID: objectID) { _ in
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
