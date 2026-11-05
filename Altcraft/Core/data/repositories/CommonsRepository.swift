//
//  CommonsRepository.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Protocol for retry-aware Core Data entities (counter + max limit), used by `retryLimit`.
@_spi(_Altcraft) public protocol RetryTrackable where Self: NSManagedObject {    /// Current number of attempts.
    var retryCount: Int16 { get set }
    /// Maximum allowed attempts (inclusive).
    var maxRetryCount: Int16 { get set }
}

/// Resolves an `NSManagedObjectID` inside `context` defensively (no URI usage).
/// Call only on the context's queue (`perform` / `performAndWait`).
func resolveObject(
    in context: NSManagedObjectContext,
    from objectID: NSManagedObjectID
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

/// Materializes an `NSManagedObject` by ID inside the given context and maps
/// it to a plain value on the context's queue.
///
/// `map` runs inside `perform`, so reading entity properties is safe. The
/// returned value must not retain managed objects — return plain values
/// (`String`, `Int`, `Data`, decoded collections, snapshots) so nothing
/// crosses the context queue boundary.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object.
///   - objectID: The `NSManagedObjectID` of the object to materialize.
///   - type: The expected `NSManagedObject` subclass type.
///   - map: Value extraction executed on the context's queue.
/// - Returns: The value produced by `map`, or throws if the object does not exist.
@_spi(_Altcraft) public func withEntity<T: NSManagedObject, R>(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    as type: T.Type,
    map: @escaping @Sendable (T) throws -> R
) async throws -> R {
    try await context.performAsync {
        guard let entity = try context.existingObject(
            with: objectID
        ) as? T else {
            throw ExceptionExtension.exception(
                CoreEvents.entityNotFoundByID
            )
        }
        return try map(entity)
    }
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
/// - Returns: `true` on success (or if the object was already gone), `false` on failure.
@_spi(_Altcraft) public func deleteEntity(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> Bool {
    await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        context.perform {
            guard let obj = resolveObject(in: context, from: objectID) else {
                cont.resume(returning: true)
                return
            }

            context.delete(obj)

            do {
                if context.hasChanges { try context.save() }
                cont.resume(returning: true)
            } catch {
                CoreLog.error(#function, error: error)
                cont.resume(returning: false)
            }
        }
    }
}

/// Increments `retryCount` for a retry-trackable entity and saves the context.
///
/// - Parameters:
///   - entity: The Core Data entity conforming to `RetryTrackable`.
///   - context: The managed object context where the change should be persisted.
///   - function: The caller function name used for error logging.
/// - Returns: `true` if the increment and save succeeded, otherwise `false`.
private func increaseRetryCount(
    for entity: NSManagedObject & RetryTrackable,
    in context: NSManagedObjectContext,
    function: String
){
    entity.retryCount += 1
    do {
        if context.hasChanges { try context.save() }
    } catch {
        CoreLog.error(function, error: error)
    }
}

/// Deletes the given Core Data object and saves the context if needed.
///
/// - Parameters:
///   - object: The object to delete from the context.
///   - context: The managed object context where the deletion should be persisted.
///   - function: The caller function name used for error logging.
/// - Returns: `true` if the deletion and save succeeded, otherwise `false`.
private func deleteEntity(
    object: NSManagedObject,
    in context: NSManagedObjectContext,
    function: String
) -> Bool {
    context.delete(object)
    do {
        if context.hasChanges { try context.save() }
        return true
    } catch {
        CoreLog.error(function, error: error); return false
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
/// - Returns:
///   - `true` when the retry limit is reached, the object is unavailable, or the object is not retry-trackable (and is deleted)
///   - `false` when the retry was incremented and more attempts are allowed.
@_spi(_Altcraft) public func retryLimit(context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> Bool {
    await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
        context.perform {
            guard let obj = resolveObject(in: context, from: objectID) else {
                cont.resume(returning: true)
                return
            }
            guard let entity = obj as? (NSManagedObject & RetryTrackable) else {
                cont.resume(
                    returning: deleteEntity(
                        object: obj, in: context, function: #function
                    )
                )
                return
            }

            let retry = Int(entity.retryCount)
            let max = Int(entity.maxRetryCount)

            if retry >= max {
                cont.resume(
                    returning: deleteEntity(
                        object: entity, in: context, function: #function
                    )
                )
            } else {
                increaseRetryCount(for: entity, in: context, function: #function)
                cont.resume( returning: false)
            }
        }
    }
}
