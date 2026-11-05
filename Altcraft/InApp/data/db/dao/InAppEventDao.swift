//
//  InAppEventDao.swift
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
enum InAppEventDAO {

    /// Creates and saves a new `InAppEventEntity` into the Core Data store, returning its `NSManagedObjectID`.
    ///
    /// Initializes a new in-app event with the given `smid`, `acid`, `type` and payload `data`,
    /// sets the timestamp and retry counters, saves it to Core Data on a background context,
    /// and returns the created object's ID.
    ///
    /// - Parameters:
    ///   - smid: The in-app message identifier.
    ///   - acid: The Altcraft campaign/action identifier.
    ///   - type: The type of the in-app event.
    ///   - data: Serialized event payload.
    /// - Returns: The created entity's `NSManagedObjectID` or `nil` if saving failed.
    static func addInAppEventEntity(
        smid: String,
        acid: String,
        type: String,
        data: Data?
    ) async -> NSManagedObjectID? {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let entity = InAppEventEntity(context: context)
                entity.time = Int64(Date().timeIntervalSince1970 * 1000)
                entity.requestId = UUID().uuidString
                entity.smid = smid
                entity.acid = acid
                entity.type = type
                entity.data = data
                entity.retryCount = 0
                entity.maxRetryCount = Constants.Retry.maxGlobalRetryCount

                try context.save()
                return entity.objectID
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Returns in-app event object IDs ordered by `time` ascending.
    static func getAllInAppEvents(
        context: NSManagedObjectContext
    ) async -> [NSManagedObjectID] {
        do {
            return try await context.performAsync {
                let request = NSFetchRequest<NSManagedObjectID>(
                    entityName: InAppConstants.EntityNames.inAppEventEntity
                )
                request.resultType = .managedObjectIDResultType
                request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                return try context.fetch(request)
            }
        } catch {
            InAppLog.error(#function, error: error)
            return []
        }
    }

    /// Clears oldest `InAppEventEntity` records when the total exceeds a threshold.
    static func clearOldInAppEvents(
        context: NSManagedObjectContext,
        threshold: Int = 500,
        purgeCount: Int = 100
    ) async {
        do {
            try await context.performAsync {
                let countReq: NSFetchRequest<InAppEventEntity> = InAppEventEntity.fetchRequest()
                let total = try context.count(for: countReq)
                guard total > threshold else { return }

                let fetchReq: NSFetchRequest<InAppEventEntity> = InAppEventEntity.fetchRequest()
                fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
                fetchReq.fetchLimit = max(0, purgeCount)

                let oldest = try context.fetch(fetchReq)
                guard !oldest.isEmpty else { return }

                oldest.forEach(context.delete)
                try context.save()
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

}
