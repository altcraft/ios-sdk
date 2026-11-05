//
//  InAppSubscribeDao.swift
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

/// Data-access operations for in-app data.
enum InAppSubscribeDAO {

    /// Adds a new entry to the `InAppSubscribeEntity` table.
    ///
    /// - Parameters:
    ///   - userTag: User tag string.
    ///   - deviceId: Device ID as UUIDv4 string.
    ///   - acid: Altcraft Client ID.
    ///   - status: Subscription status string.
    ///   - sync: Sync mode flag.
    ///   - profileFields: Optional profile fields to serialize and store.
    ///   - customFields: Optional custom fields to serialize and store.
    ///   - cats: Optional list of categories to store.
    ///   - replace: Whether this entry should replace existing one.
    ///   - skipTriggers: Whether triggers should be skipped.
    /// - Returns: `.success(())` if saved, otherwise `.failure(error)`.
    static func addInAppSubscribeEntity(
        userTag: String,
        deviceId: String,
        acid: String,
        status: String,
        sync: Bool,
        profileFields: Data?,
        customFields: Data?,
        cats: Data?,
        replace: Bool?,
        skipTriggers: Bool?
    ) async -> Result<Void, Error> {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let newEntity = InAppSubscribeEntity(context: context)
                newEntity.time = Int64(Date().timeIntervalSince1970 * 1000)
                newEntity.requestId = UUID().uuidString
                newEntity.userTag = userTag
                newEntity.status = status
                newEntity.deviceId = deviceId
                newEntity.acid = acid
                newEntity.sync = sync
                newEntity.replace = replace ?? false
                newEntity.skipTriggers = skipTriggers ?? false
                newEntity.cats = cats
                newEntity.profileFields = profileFields
                newEntity.customFields = customFields
                newEntity.retryCount = 0
                newEntity.maxRetryCount = Constants.Retry.maxGlobalRetryCount

                try context.save()
            }
            return .success(())
        } catch {
            InAppLog.error(#function, error: error)
            return .failure(error)
        }
    }

    /// Fetches object IDs of all `InAppSubscribeEntity` rows where `userTag` matches.
    ///
    /// - Parameters:
    ///   - context: The `NSManagedObjectContext` used for Core Data operations.
    ///   - userTag: Tag used to filter In-App subscriptions.
    /// - Returns: Array of `NSManagedObjectID`.
    static func getAllInAppSubscriptionsByTag(
        context: NSManagedObjectContext,
        userTag: String
    ) async -> [NSManagedObjectID] {
        do {
            return try await context.performAsync {
                let request = NSFetchRequest<NSManagedObjectID>(
                    entityName: InAppConstants.EntityNames.inAppSubscribeEntity
                )
                request.resultType = .managedObjectIDResultType
                request.predicate = NSPredicate(format: "userTag == %@", userTag)
                request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                return try context.fetch(request)
            }
        } catch {
            InAppLog.error(#function, error: error)
            return []
        }
    }

    /// Clears oldest `InAppSubscribeEntity` records when the total exceeds a threshold.
    ///
    /// Deletion is based on the `time` field in ascending order, oldest first.
    ///
    /// - Parameters:
    ///   - context: Managed object context used for the operation.
    ///   - threshold: Maximum allowed number of records before cleanup starts. Default is `500`.
    ///   - purgeCount: Number of oldest records to delete when threshold is exceeded. Default is `100`.
    static func clearOldInAppSubscriptions(
        context: NSManagedObjectContext,
        threshold: Int = 500,
        purgeCount: Int = 100
    ) async {
        do {
            try await context.performAsync {
                let countReq: NSFetchRequest<InAppSubscribeEntity> = InAppSubscribeEntity.fetchRequest()
                let total = try context.count(for: countReq)
                guard total > threshold else { return }

                let fetchReq: NSFetchRequest<InAppSubscribeEntity> = InAppSubscribeEntity.fetchRequest()
                fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                fetchReq.fetchLimit = purgeCount

                let oldest = try context.fetch(fetchReq)
                guard !oldest.isEmpty else { return }

                oldest.forEach(context.delete)
                try context.save()
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes all stored in-app subscription requests.
    ///
    /// Used during authentication state changes
    /// when pending subscription requests become invalid.
    ///
    /// Rows are removed with fetch-and-delete: `NSBatchDeleteRequest` is not
    /// supported by the in-memory stores used by the test bundle and can
    /// raise an Objective-C exception instead of a regular Swift error.
    static func deleteAllInAppSubscribeEntities() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                try InAppDAO.deleteAllObjects(
                    of: InAppSubscribeEntity.self,
                    in: context
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

}
