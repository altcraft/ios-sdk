//
//  MobileEventDbQueries.swift
//  Altcraft
//
//  Created by andrey on 06.10.2025.
//

import Foundation
import CoreData

/// Inserts a `MobileEventEntity` into Core Data.
/// Converts maps/objects to JSON (`Data`) where needed.
/// Does **not** log on failure; error is returned via `completion`.
///
/// - Parameters:
///   - userTag: User tag to bind the event to.
///   - timeZone: Timezone offset in minutes (signed).
///   - sid: The string ID of the pixel.
///   - eventName: Event name.
///   - altcraftClientID: Altcraft client identifier.
///   - payload: Arbitrary payload as `[String: Any?]?` (serialized to JSON).
///   - matching: Matching parameters as `[String: Any?]?` (serialized to JSON).
///   - profileFields: Profile fields as `[String: Any?]?` (serialized to JSON).
///   - subscription: Subscription model to attach (encoded to JSON).
///   - sendMessageId: SMID.
///   - matchingType: Type of matching (e.g., `"push_sub"`, `"email"`, etc.).
///   - utmTags: Optional UTM tags for campaign attribution (e.g. `source`, `medium`,
///              `campaign`, `term`, `content`). If provided, they are encoded
///              and persisted with the event for downstream analytics.
///   - completion: `.success(())` on save, `.failure(error)` on error.
func addMobileEventEntity(
    userTag: String,
    timeZone: Int16,
    sid: String,
    eventName: String,
    altcraftClientID: String?,
    payload: [String: Any?]?,
    matching: [String: Any?]?,
    profileFields: [String: Any?]?,
    subscription: (any Subscription)? = nil,
    sendMessageId: String?,
    matchingType: String? = nil,
    utmTags: UTM? = nil,
    completion: @escaping (Result<Void, Error>) -> Void
) {
    withBackgroundContext { context in
        do {
            let entity = MobileEventEntity(context: context)
            entity.userTag = userTag
            entity.timeZone = timeZone
            entity.time = Int64(Date().timeIntervalSince1970 * 1000)
            entity.sid = sid
            entity.altcraftClientID = altcraftClientID
            entity.eventName = eventName
            entity.payload = encodeAnyMap(payload)
            entity.matching = encodeAnyMap(matching)
            entity.profileFields = encodeAnyMap(profileFields)
            entity.subscription = encodeSubscription(subscription)
            entity.sendMessageId = sendMessageId
            entity.retryCount = 0
            entity.maxRetryCount = 15
            entity.matchingType = matchingType
            entity.utmTags = encodeUTM(utmTags)

            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
}

/// Returns mobile events object IDs filtered by `userTag`, ordered by `time` ascending.
///
/// - Parameters:
///   - context: The Core Data context to perform the fetch in.
///   - userTag: Tag to filter by.
///   - completion: Callback with fetched object IDs (empty on failure).
func getAllMobileEventsByTag(
    context: NSManagedObjectContext,
    userTag: String,
    completion: @escaping ([NSManagedObjectID]) -> Void
) {
    context.perform {
        let request = NSFetchRequest<NSManagedObjectID>(
            entityName: Constants.EntityNames.mobileEvent)
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

/// Deletes the `MobileEventEntity` with the given object ID from Core Data.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - objectID: The `NSManagedObjectID` of the entity to delete.
///   - completion: A closure called with `true` on success (or if already gone / wrong type), `false` on failure.
func deleteMobileEvent(
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

/// Increments retry counter or deletes the mobile event when max retries are reached.
///
/// - Parameters:
///   - context: Managed object context used to persist changes.
///   - objectID: `NSManagedObjectID` of `MobileEventEntity` to update or delete.
///   - completion: `true` if the entity was deleted (limit reached or missing/wrong type), `false` otherwise.
func mobileEventLimit(
    context: NSManagedObjectContext,
    for objectID: NSManagedObjectID,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        guard let materialized = try? context.existingObject(with: objectID) else {
            completion(true)
            return
        }
        
        guard let entity = materialized as? MobileEventEntity else {
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
            deleteMobileEvent(context: context, objectID: objectID) { _ in
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

/// Clears oldest `MobileEventEntity` records when the total exceeds a threshold (push-like behavior).
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - threshold: Maximum allowed number of records before cleanup starts (default: 500).
///   - purgeCount: Number of oldest records to delete when threshold is exceeded (default: 100).
///   - completion: Called when the operation finishes, regardless of outcome.
func clearOldMobileEvents(
    context: NSManagedObjectContext,
    threshold: Int = 500,
    purgeCount: Int = 100,
    completion: @escaping () -> Void
) {
    context.perform {
        defer { completion() }

        do {
            // Count total records
            let countReq: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
            let total = try context.count(for: countReq)
            guard total > threshold else { return }

            // Fetch oldest N by time
            let fetchReq: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
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
