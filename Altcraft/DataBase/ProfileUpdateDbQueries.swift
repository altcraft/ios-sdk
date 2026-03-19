//
//  ProfileUpdateDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
import CoreData

/// Inserts a `ProfileUpdateEntity` into Core Data.
/// Converts maps/objects to JSON (`Data`) where needed.
///
/// - Parameters:
///   - userTag: User tag to bind the profile update to.
///   - profileFields: Profile fields as `Data?`.
///   - skipTriggers: If `true`, automation triggers (e.g., autoresponders) will be skipped.
///   - maxRetryCount: Maximum retry attempts for this record (default: 15).
/// - Returns: `.success(())` on save, `.failure(error)` on error.
func addProfileUpdateEntity(
    userTag: String,
    profileFields: Data?,
    skipTriggers: Bool = false,
    maxRetryCount: Int16 = 15
) async -> Result<Void, Error> {
    do {
        try await CoreDataManager.shared.performBackgroundTask { context in
            let entity = ProfileUpdateEntity(context: context)
            entity.userTag = userTag
            entity.requestId = UUID().uuidString
            entity.time = Int64(Date().timeIntervalSince1970 * 1000)
            entity.profileFields = profileFields
            entity.skipTriggers = skipTriggers
            entity.retryCount = 0
            entity.maxRetryCount = maxRetryCount

            try context.save()
        }
        return .success(())
    } catch {
        errorEvent(#function, error: error)
        return .failure(error)
    }
}

/// Returns profile updates object IDs filtered by `userTag`, ordered by `time` ascending.
///
/// - Parameters:
///   - context: The Core Data context to perform the fetch in.
///   - userTag: Tag to filter by.
/// - Returns: Fetched object IDs, or an empty array on failure.
func getAllProfileUpdatesByTag(
    context: NSManagedObjectContext,
    userTag: String
) async -> [NSManagedObjectID] {
    do {
        return try await context.performAsync {
            let request = NSFetchRequest<NSManagedObjectID>(
                entityName: Constants.EntityNames.profileUpdateEntity
            )
            request.resultType = .managedObjectIDResultType
            request.predicate = NSPredicate(format: "userTag == %@", userTag)
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]

            return try context.fetch(request)
        }
    } catch {
        errorEvent(#function, error: error)
        return []
    }
}

/// Clears oldest `ProfileUpdateEntity` records when the total exceeds a threshold.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts.
///   - purgeCount: Number of oldest records to delete when threshold is exceeded.
func clearOldProfileUpdates(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100
) async {
    do {
        try await context.performAsync {
            let countReq: NSFetchRequest<ProfileUpdateEntity> = ProfileUpdateEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            let fetchReq: NSFetchRequest<ProfileUpdateEntity> = ProfileUpdateEntity.fetchRequest()
            fetchReq.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            fetchReq.fetchLimit = max(0, purgeCount)

            let oldest = try context.fetch(fetchReq)
            guard !oldest.isEmpty else { return }

            oldest.forEach { context.delete($0) }

            if context.hasChanges {
                try context.save()
            }
        }
    } catch {
        errorEvent(#function, error: error)
    }
}
