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
    completion: @escaping (Result<Void, Error>) -> Void
) {
    withBackgroundContext { context in
        do {
            let newEntity = SubscribeEntity(context: context)
            newEntity.time = Int64(Date().timeIntervalSince1970 * 1000)
            newEntity.requestId = UUID().uuidString
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

/// Clears oldest `SubscribeEntity` records when the total exceeds a threshold.
///
/// Deletion is based on the `time` field in ascending order (oldest first),
/// mirroring the cleanup strategy used for `PushEventEntity`.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts (default: 500).
///   - purgeCount: Number of oldest records to delete when threshold is exceeded (default: 100).
///   - completion: Called when the operation finishes, regardless of outcome.
func clearOldSubscriptions(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100,
    completion: @escaping () -> Void
) {
    context.perform {
        defer { completion() }

        do {
            let countReq: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            let fetchReq: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
            fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            fetchReq.fetchLimit = max(0, purgeCount)

            let oldest = try context.fetch(fetchReq)
            guard !oldest.isEmpty else { return }

            oldest.forEach { context.delete($0) }
            try context.save()

        } catch {
            errorEvent(#function, error: error)
        }
    }
}
