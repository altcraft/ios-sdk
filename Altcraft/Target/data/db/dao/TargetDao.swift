//
//  TargetDao.swift
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

/// Namespace for target entity data access.
enum TargetDAO {

/// Inserts a `TargetEntity` into Core Data.
///
/// - Parameters:
///   - userTag: User tag to bind the event to.
///   - timeZone: Timezone offset in minutes.
///   - sid: Pixel identifier.
///   - eventName: Event name.
///   - altcraftClientID: Altcraft client identifier.
///   - payloadData: Encoded payload JSON data.
///   - matchingData: Encoded matching JSON data.
///   - profileFieldsData: Encoded profile fields JSON data.
///   - subscriptionData: Encoded subscription data.
///   - sendMessageId: Send message identifier.
///   - matchingType: Matching type.
///   - utmTagsData: Encoded UTM data.
/// - Returns: `.success(())` on success, `.failure(error)` on failure.
static func addTargetEntity(
    sid: String,
    userTag: String,
    timeZone: Int16,
    eventName: String,
    payloadData: Data?,
    matchingData: Data?,
    sendMessageId: String?,
    matchingType: String? = nil,
    utmTagsData: Data? = nil,
    altcraftClientID: String?,
    profileFieldsData: Data?,
    subscriptionData: Data?
) async -> Result<Void, Error> {
    do {
        try await targetDatabase.performBackgroundTask { context in
            let entity = TargetEntity(context: context)
            entity.userTag = userTag
            entity.requestId = UUID().uuidString
            entity.timeZone = timeZone
            entity.time = Int64(Date().timeIntervalSince1970)
            entity.sid = sid
            entity.altcraftClientID = altcraftClientID
            entity.eventName = eventName
            entity.payload = payloadData
            entity.matching = matchingData
            entity.profileFields = profileFieldsData
            entity.subscription = subscriptionData
            entity.sendMessageId = sendMessageId
            entity.retryCount = 0
            entity.maxRetryCount = Constants.Retry.maxGlobalRetryCount
            entity.matchingType = matchingType
            entity.utmTags = utmTagsData

            try context.save()
        }
        return .success(())
    } catch {
        TargetLog.error(#function, error: error)
        return .failure(error)
    }
}

/// Returns mobile events object IDs filtered by `userTag`, ordered by `time` ascending.
///
/// - Parameters:
///   - context: The Core Data context to perform the fetch in.
///   - userTag: Tag to filter by.
/// - Returns: Fetched object IDs.
/// - Throws: Rethrows Core Data fetch errors; a failed fetch is not
///   equivalent to an empty queue.
static func getAllTargetsByTag(
    context: NSManagedObjectContext,
    userTag: String
) async throws -> [NSManagedObjectID] {
    try await context.performAsync {
        let request = NSFetchRequest<NSManagedObjectID>(
            entityName: TargetConstants.EntityNames.targetEventEntity
        )
        request.resultType = .managedObjectIDResultType
        request.predicate = NSPredicate(format: "userTag == %@", userTag)
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]

        return try context.fetch(request)
    }
}

/// Clears oldest `TargetEntity` records when the total exceeds a threshold (push-like behavior).
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts.
///   - purgeCount: Number of oldest records to delete when threshold is exceeded.
static func clearOldTargets(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100
) async {
    do {
        try await context.performAsync {
            let countReq: NSFetchRequest<TargetEntity> = TargetEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            let fetchReq: NSFetchRequest<TargetEntity> = TargetEntity.fetchRequest()
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
        TargetLog.error(#function, error: error)
    }
}
}
