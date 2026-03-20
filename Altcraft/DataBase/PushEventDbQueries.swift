//
//  PushEventDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Creates and saves a new `PushEventEntity` into the Core Data store, returning its `NSManagedObjectID`.
///
/// Initializes a new push event with the given `uid` and `type`, sets the timestamp and retry counters,
/// saves it to Core Data on a background context, and returns the created object's ID.
///
/// - Parameters:
///   - uid: The unique identifier of the push event.
///   - type: The type of the push event (e.g., "delivery", "open").
/// - Returns: The created entity's `NSManagedObjectID` or `nil` if saving failed.
func addPushEventEntity(
    uid: String,
    type: String
) async -> NSManagedObjectID? {
    do {
        return try await CoreDataManager.shared.performBackgroundTask { context in
            let entity = PushEventEntity(context: context)
            entity.time = Int64(Date().timeIntervalSince1970 * 1000)
            entity.requestId = UUID().uuidString
            entity.uid = uid
            entity.type = type
            entity.retryCount = 0
            entity.maxRetryCount = 15

            try context.save()
            return entity.objectID
        }
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Returns push event object IDs ordered by `time` ascending.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the fetch.
/// - Returns: Fetched object IDs (empty on failure).
func getAllPushEvents(
    context: NSManagedObjectContext
) async -> [NSManagedObjectID] {
    do {
        return try await context.performAsync {
            let request = NSFetchRequest<NSManagedObjectID>(
                entityName: Constants.EntityNames.pushEventEntity
            )
            request.resultType = .managedObjectIDResultType
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            return try context.fetch(request)
        }
    } catch {
        errorEvent(#function, error: error)
        return []
    }
}

/// Clears oldest `PushEventEntity` records when the total exceeds a threshold (mobile-like behavior).
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts (default: 500).
///   - purgeCount: Number of oldest records to delete when threshold is exceeded (default: 100).
func clearOldPushEvents(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100
) async {
    do {
        try await context.performAsync {
            let countReq: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            let fetchReq: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            fetchReq.fetchLimit = max(0, purgeCount)

            let oldest = try context.fetch(fetchReq)
            guard !oldest.isEmpty else { return }

            oldest.forEach(context.delete)
            try context.save()
        }
    } catch {
        errorEvent(#function, error: error)
    }
}
