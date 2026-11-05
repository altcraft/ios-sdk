//
//  PushSubscribeDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Data-access operations for push subscription entities.
enum PushSubscribeDAO {

    /// Adds a new entry to the `PushSubscribeEntity` table.
    ///
    /// - Parameters:
    ///   - userTag: User tag string.
    ///   - status: Subscription status string.
    ///   - sync: Sync mode flag.
    ///   - profileFields: Optional profile fields to serialize and store.
    ///   - customFields: Optional custom fields to serialize and store.
    ///   - cats: Optional list of categories to store.
    ///   - replace: Whether this entry should replace existing one.
    ///   - skipTriggers: Whether triggers should be skipped.
    /// - Returns: `.success(())` if saved, otherwise `.failure(error)`.
    static func addSubscribeEntity(
        userTag: String,
        status: String,
        sync: Bool,
        profileFields: Data?,
        customFields: Data?,
        cats: Data?,
        replace: Bool?,
        skipTriggers: Bool?
    ) async -> Result<Void, Error> {
        do {
            try await pushDatabase.performBackgroundTask { context in
                let newEntity = PushSubscribeEntity(context: context)
                newEntity.time = Int64(Date().timeIntervalSince1970)
                newEntity.requestId = UUID().uuidString
                newEntity.userTag = userTag
                newEntity.status = status
                newEntity.sync = sync
                newEntity.replace = replace ?? false
                newEntity.skipTriggers = skipTriggers ?? false
                newEntity.cats = cats
                newEntity.profileFields = profileFields
                newEntity.customFields = customFields
                newEntity.retryCount = 0
                newEntity.maxRetryCount = 15

                try context.save()
            }
            return .success(())
        } catch {
            PushLog.error(#function, error: error)
            return .failure(error)
        }
    }

    /// Fetches object IDs of all `PushSubscribeEntity` rows where `userTag` matches.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` used for Core Data operations.
    ///   - userTag: Tag used to filter subscriptions.
    /// - Returns: Array of `NSManagedObjectID`.
    static func getAllSubscriptionsByTag(
        context: NSManagedObjectContext,
        userTag: String
    ) async -> [NSManagedObjectID] {
        do {
            return try await context.performAsync {
                let request = NSFetchRequest<NSManagedObjectID>(
                    entityName: PushConstants.EntityNames.subscribeEntity
                )
                request.resultType = .managedObjectIDResultType
                request.predicate = NSPredicate(format: "userTag == %@", userTag)
                request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                return try context.fetch(request)
            }
        } catch {
            PushLog.error(#function, error: error)
            return []
        }
    }

    /// Clears oldest `PushSubscribeEntity` records when the total exceeds a threshold.
    ///
    /// Deletion is based on the `time` field in ascending order (oldest first).
    ///
    /// - Parameters:
    ///   - context: Managed object context used for the operation.
    ///   - threshold: Maximum allowed number of records before cleanup starts (default: 500).
    ///   - purgeCount: Number of oldest records to delete when threshold is exceeded (default: 100).
    static func clearOldSubscriptions(
        context: NSManagedObjectContext,
        threshold: Int = 500,
        purgeCount: Int = 100
    ) async {
        do {
            try await context.performAsync {
                let countReq: NSFetchRequest<PushSubscribeEntity> = PushSubscribeEntity.fetchRequest()
                let total = try context.count(for: countReq)
                guard total > threshold else { return }

                let fetchReq: NSFetchRequest<PushSubscribeEntity> = PushSubscribeEntity.fetchRequest()
                fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                fetchReq.fetchLimit = purgeCount

                let oldest = try context.fetch(fetchReq)
                guard !oldest.isEmpty else { return }

                oldest.forEach(context.delete)
                try context.save()
            }
        } catch {
            PushLog.error(#function, error: error)
        }
    }
}
