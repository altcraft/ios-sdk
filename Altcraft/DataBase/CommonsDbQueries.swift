//
//  CommonsDbQueries.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Protocol for retry-aware Core Data entities (counter + max limit), used by `retryLimit`.
protocol RetryTrackable where Self: NSManagedObject {
    /// Current number of attempts.
    var retryCount: Int16 { get set }
    /// Maximum allowed attempts (inclusive).
    var maxRetryCount: Int16 { get set }
}

/// Enables retry logic for push events via `retryLimit`.
extension PushEventEntity: RetryTrackable {}

/// Enables retry logic for subscriptions via `retryLimit`.
extension SubscribeEntity: RetryTrackable {}

/// Enables retry logic for mobile events via `retryLimit`.
extension MobileEventEntity: RetryTrackable {}

/// Resolves an `NSManagedObjectID` inside `context` defensively (no URI usage).
/// Call only on the context's queue (`perform` / `performAndWait`).
func resolveObject(
    in context: NSManagedObjectContext, from objectID: NSManagedObjectID
) -> NSManagedObject? {
    guard !objectID.isTemporaryID, let psc = context.persistentStoreCoordinator else {
        return nil
    }
    guard let store = objectID.persistentStore, psc.persistentStores.contains(store) else {
        return nil
    }
    guard let obj = try? context.existingObject(with: objectID), !obj.isDeleted else {
        return nil
    }
    return obj
}

/// Deletes a Core Data entity with the given `NSManagedObjectID`.
///
/// Safely resolves and deletes any managed object, regardless of its entity type.
/// Safe to use across parallel tasks and entity kinds, as it rehydrates the object
/// within the provided context before deletion.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` to perform the delete on (use its own queue).
///   - objectID: Permanent `NSManagedObjectID` of the entity to delete.
///   - completion: Called with `true` on success (or if the object was already gone), `false` on failure.
func deleteEntity(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: ((Bool) -> Void)? = nil
) {
    context.perform {
        guard let obj = resolveObject(in: context, from: objectID) else {
            completion?(true)
            return
        }
        context.delete(obj)
        do {
            if context.hasChanges { try context.save() }
            completion?(true)
        } catch {
            errorEvent(#function, error: error)
            completion?(false)
        }
    }
}

/// Applies retry-limit logic for an entity referenced by `objectID`.
///
/// If the resolved object conforms to `RetryTrackable`, increments `retryCount` until it reaches
/// `maxRetryCount`; once exhausted, deletes the entity. If the object is of a different type,
/// deletes it and returns `true`.
///
/// - Parameters:
///   - context: Background `NSManagedObjectContext` to perform Core Data operations on.
///   - objectID: Permanent `NSManagedObjectID` of the target entity.
///   - completion: Called with `true` when the retry limit is reached or the object is unavailable;
///                 `false` when the retry was incremented and more attempts are allowed.
func retryLimit(
    context: NSManagedObjectContext,
    for objectID: NSManagedObjectID,
    completion: @escaping (Bool) -> Void
) {
    context.perform {
        guard let obj = resolveObject(in: context, from: objectID) else {
            completion(true)
            return
        }

        guard let entity = obj as? (NSManagedObject & RetryTrackable) else {
            context.delete(obj)
            do { if context.hasChanges { try context.save() } } catch {
                errorEvent(#function, error: error)
            }
            completion(true)
            return
        }

        let retry = Int(entity.retryCount)
        let max = Int(entity.maxRetryCount)

        if retry >= max {
            context.delete(entity)
            do {
                if context.hasChanges { try context.save() }
                completion(true)
            } catch {
                errorEvent(#function, error: error)
                completion(true)
            }
        } else {
            entity.retryCount = Int16(retry + 1)
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
