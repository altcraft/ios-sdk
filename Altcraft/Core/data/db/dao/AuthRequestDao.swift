//
//  AuthRequestDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Inserts or replaces the stored authorization request.
///
/// Existing records are merged into a single entity.
/// Duplicate rows are removed automatically.
///
/// - Parameters:
///   - userTag: User identifier associated with the auth request.
///   - requestId: Unique request identifier.
///   - maxRetryCount: Maximum allowed retry count before deletion.
func addAuthRequestEntity(
    userTag: String,
    requestId: String = UUID().uuidString,
    maxRetryCount: Int16 = 15
) async {
    do {
        try await CoreDataManager.shared.performBackgroundTask { context in
            let request = AuthRequestEntity.fetchRequest()

            let results = try context.fetch(request)
            let entity = results.first ?? AuthRequestEntity(context: context)

            for duplicate in results.dropFirst() {
                context.delete(duplicate)
            }

            entity.requestId = requestId
            entity.userTag = userTag
            entity.retryCount = 0
            entity.maxRetryCount = maxRetryCount

            if context.hasChanges {
                try context.save()
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Value snapshot of a stored auth request.
///
/// Fields are read on the context's queue; the snapshot contains only plain
/// values (`NSManagedObjectID` is queue-safe), so it can cross concurrency
/// domains.
struct AuthRequestSnapshot {
    let userTag: String?
    let objectID: NSManagedObjectID
}

/// Returns a snapshot of the stored authorization request.
///
/// - Parameter context: Managed object context.
/// - Returns: Snapshot of the stored authorization request or `nil`.
func getAuthRequestSnapshot(
    context: NSManagedObjectContext
) async -> AuthRequestSnapshot? {
    do {
        return try await context.performAsync {
            let request = AuthRequestEntity.fetchRequest()

            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first else {
                return nil
            }

            return AuthRequestSnapshot(
                userTag: entity.userTag,
                objectID: entity.objectID
            )
        }
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Deletes all stored authorization requests.
///
/// Used during authentication state changes
/// when pending requests become invalid.
///
/// Rows are removed with fetch-and-delete: `NSBatchDeleteRequest` is not
/// supported by the in-memory stores used by the test bundle and can raise
/// an Objective-C exception instead of a regular Swift error.
///
/// - Parameter context: Managed object context.
func deleteAllAuthRequests(
    context: NSManagedObjectContext
) {
    context.perform {
        let request = NSFetchRequest<NSManagedObject>(
            entityName: Constants.EntityNames.authRequestEntity
        )
        request.includesPropertyValues = false

        do {
            let results = try context.fetch(request)
            results.forEach(context.delete)

            if context.hasChanges {
                try context.save()
            }
        } catch {
            CoreLog.error(#function, error: error)
        }
    }
}
