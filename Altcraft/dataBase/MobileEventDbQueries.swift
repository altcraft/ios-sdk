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
///   - context: Managed object context used for the operation.
///   - userTag: User tag to bind the event to.
///   - timeZone: Timezone offset in minutes (signed).
///   - time: Unix timestamp in seconds.
///   - sid: The string ID of the pixel.
///   - altcraftClientID: Altcraft client identifier.
///   - eventName: Event name.
///   - payload: Arbitrary payload as `[String: Any?]?` (serialized to JSON).
///   - matching: Matching map as `[String: Any?]?` (serialized to JSON).
///   - matchingType: Type of matching (e.g., `"push_sub"`, `"email"`, etc.).
///   - profileFields: Profile fields as `[String: Any?]?` (serialized to JSON).
///   - subscription: Subscription model to attach (encoded to JSON).
///   - sendMessageId: SMID.
///   - completion: `.success(())` on save, `.failure(error)` on error.
func addMobileEventEntity(
    context: NSManagedObjectContext,
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

        // Новые поля
        entity.matchingType = matchingType
        entity.utmTags = encodeUTM(utmTags)

        try context.save()
        completion(.success(()))
    } catch {
        completion(.failure(error))
    }
}


/// Returns mobile events filtered by `userTag`, ordered by `time` ascending.
/// - Parameters:
///   - context: Core Data context to perform the fetch in.x
///   - userTag: Tag to filter by; pass `nil` to fetch records where `userTag == nil`.
///   - completion: Callback with fetched events (empty on failure).
func getAllMobileEvents(
    context: NSManagedObjectContext,
    userTag: String,
    completion: @escaping ([MobileEventEntity]) -> Void
) {
    context.perform {
        let fetchRequest: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
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

/// Deletes the given `MobileEventEntity` from the Core Data context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to perform the delete operation.
///   - entity: The `MobileEventEntity` instance to delete.
///   - completion: A closure called with `true` on success, `false` on failure.
func deleteMobileEvent(
    context: NSManagedObjectContext,
    entity: MobileEventEntity,
    completion: ((Bool) -> Void)? = nil
) {
    context.perform {
        do {
            context.delete(entity)
            try context.save()
            completion?(true)
        } catch {
            errorEvent(#function, error: error)
            completion?(false)
        }
    }
}

/// Deletes all mobile events using batch delete.
/// - Parameters:
///   - context: Core Data context to perform the batch delete in.
///   - completion: Result with deleted count or error.
func deleteAllMobileEvents(
    context: NSManagedObjectContext,
    completion: @escaping (Result<Int, Error>) -> Void
) {
    context.perform {
        let fetch: NSFetchRequest<NSFetchRequestResult> = MobileEventEntity.fetchRequest()
        let deleteReq = NSBatchDeleteRequest(fetchRequest: fetch)
        deleteReq.resultType = .resultTypeCount
        do {
            if let res = try context.execute(deleteReq) as? NSBatchDeleteResult,
               let count = res.result as? Int {
                context.reset()
                completion(.success(count))
            } else {
                context.reset()
                completion(.success(0))
            }
        } catch {
            completion(.failure(error))
        }
    }
}


/// Increments retry counter or deletes the mobile event when max retries are reached.
/// - Parameters:
///   - context: Managed object context used to persist changes.
///   - entity: MobileEventEntity to update or delete.
///   - completion: `true` if the entity was deleted (limit reached), `false` otherwise.
func mobileEventLimit(
    context: NSManagedObjectContext,
    for entity: MobileEventEntity,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        let retryCount = Int(entity.retryCount)
        let maxRetryCount = Int(entity.maxRetryCount)

        if retryCount >= maxRetryCount {
            deleteMobileEvent(context: context, entity: entity) { _ in
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
