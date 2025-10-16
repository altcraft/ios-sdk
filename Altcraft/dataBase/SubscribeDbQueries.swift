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
///   - context: The `NSManagedObjectContext` used to perform the operation.
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
    context: NSManagedObjectContext,
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
    do {
        let newEntity = SubscribeEntity(context: context)
        newEntity.time = Int64(Date().timeIntervalSince1970 * 1000)
        newEntity.uid = uid
        newEntity.userTag = userTag
        newEntity.status = status
        newEntity.sync = Int16(sync)
        newEntity.replace = replace ?? false
        newEntity.skipTriggers = skipTriggers ?? false
        newEntity.retryCount = 0
        newEntity.maxRetryCount = 15
        newEntity.cats = encodeCats(cats)
        newEntity.profileFields = encodeAnyMap(profileFields)
        newEntity.customFields = encodeAnyMap(customFields)

        try context.save()
        completion(.success(()))
    } catch {
        completion(.failure(error))
    }
}

/// Fetches all subscription entities from the `SubscribeEntity` table where `userTag` matches the provided tag.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used for Core Data operations.
///   - userTag: The tag used to filter subscriptions.
///   - completion: A closure that returns an array of `SubscribeEntity` objects.
func getAllSubscribeByTag(
    context: NSManagedObjectContext,
    userTag: String,
    completion: @escaping ([SubscribeEntity]) -> Void
) {
    context.perform {
        let fetchRequest: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "userTag == %@", userTag)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]

        do {
            let entities = try context.fetch(fetchRequest)
            completion(entities)
        } catch {
            errorEvent(#function, error: error)
            completion([])
        }
    }
}

/// Deletes the given `SubscribeEntity` from the Core Data context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - entity: The `SubscribeEntity` instance to delete.
///   - completion: A closure called with a `Bool` value indicating success (`true`) or failure (`false`).
///
/// - Note: This function performs the delete operation asynchronously within the `context.perform` block.
func deleteSubscribe(
    context: NSManagedObjectContext,
    entity: SubscribeEntity,
    completion: ((Bool) -> Void)? = nil
) {
    do {
        context.delete(entity)
        try context.save()
        completion?(true)
    } catch {
        errorEvent(#function, error: error)
        completion?(false)
    }
}

/// Checks the retry limit for a given subscription entity and updates its retry count if needed.
///
/// Compares `retryCount` with `maxRetryCount`.
/// If the retry count is below the limit, increments it and saves the entity.
/// If it exceeds or equals the limit, deletes the entity.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to update or delete the subscription entity.
///   - entity: The `SubscribeEntity` instance to check and update.
///   - completion: A closure called with `true` if the entity was deleted, or `false` if it was updated.
///
/// - Note: If the retry limit is exceeded, the entity is deleted and `true` is returned.
/// If the count is incremented, `false` is returned.
func subscribeLimit(
    context: NSManagedObjectContext,
    for entity: SubscribeEntity,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        let retryCount = Int(entity.retryCount)
        let maxRetryCount = Int(entity.maxRetryCount)
        
        if retryCount >= maxRetryCount {
            deleteSubscribe(context: context, entity: entity) { _ in
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

