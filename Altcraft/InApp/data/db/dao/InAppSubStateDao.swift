//
//  InAppSubStateDao.swift
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
enum InAppSubStateDAO {

    /// Inserts or replaces an `InAppSubStateEntity` in Core Data.
    ///
    /// State is stored per `userTag`, so existing record with the same `userTag`
    /// is updated instead of creating a duplicate.
    ///
    /// - Parameters:
    ///   - userTag: SDK user tag.
    ///   - status: Raw in-app subscription status.
    /// - Returns: `.success(())` on success, `.failure(error)` on failure.
    static func setInAppSubStateEntity(
        userTag: String,
        status: String
    ) async -> Result<Void, Error> {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppSubStateEntity> = InAppSubStateEntity.fetchRequest()
                request.predicate = NSPredicate(format: "userTag == %@", userTag)
                request.fetchLimit = 1

                let entity = try context.fetch(request).first ?? InAppSubStateEntity(context: context)

                entity.userTag = userTag
                entity.status = status

                if context.hasChanges {
                    try context.save()
                }
            }

            return .success(())
        } catch {
            InAppLog.error(#function, error: error)
            return .failure(error)
        }
    }

    /// Returns the stored in-app subscription status for the specified user tag.
    ///
    /// The value is read on the context's queue.
    ///
    /// - Parameters:
    ///   - userTag: SDK user tag.
    ///   - context: The Core Data context to perform the fetch in.
    /// - Returns: Stored status, or `nil` if it does not exist.
    static func getInAppSubStateStatus(
        userTag: String,
        context: NSManagedObjectContext
    ) async -> String? {
        do {
            return try await context.performAsync {
                let request: NSFetchRequest<InAppSubStateEntity> = InAppSubStateEntity.fetchRequest()
                request.predicate = NSPredicate(format: "userTag == %@", userTag)
                request.fetchLimit = 1

                return try context.fetch(request).first?.status
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Deletes all stored `InAppSubStateEntity` records.
    ///
    /// Rows are removed with fetch-and-delete: `NSBatchDeleteRequest` is not
    /// supported by the in-memory stores used by the test bundle and can
    /// raise an Objective-C exception instead of a regular Swift error.
    static func clearInAppSubStateData() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                try InAppDAO.deleteAllObjects(
                    of: InAppSubStateEntity.self,
                    in: context
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

}
