//
//  InAppStaticDao.swift
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
enum InAppStaticDAO {

    /// Saves static In-App resources into `InAppStaticEntity`.
    ///
    /// Only one row is allowed. Existing rows are removed before inserting a new one.
    ///
    /// Rows are removed with fetch-and-delete: `NSBatchDeleteRequest` is not
    /// supported by the in-memory stores used by the test bundle.
    ///
    /// - Parameters:
    ///   - blockCss: CSS for In-App block.
    ///   - blockJs: JavaScript for In-App block.
    ///   - inAppLibraryJs: In-App library JavaScript.
    static func saveInAppStaticEntity(
        blockCss: String,
        blockJs: String,
        inAppLibraryJs: String
    ) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in

                let fetchRequest: NSFetchRequest<InAppStaticEntity> =
                    InAppStaticEntity.fetchRequest()

                let stale = try context.fetch(fetchRequest)
                stale.forEach(context.delete)

                let entity = InAppStaticEntity(context: context)
                entity.createdAt = Int64(Date().timeIntervalSince1970 * 1000)
                entity.blockCss = blockCss
                entity.blockJs = blockJs
                entity.inAppLibraryJs = inAppLibraryJs

                try context.save()
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Fetches static In-App resources as plain data.
    ///
    /// Core Data entity is read only inside its managed object context.
    /// Outside the context, only safe Swift values are returned.
    ///
    /// - Parameter context: The `NSManagedObjectContext` used for Core Data operations.
    /// - Returns: Static bundle with creation time if exists, otherwise `nil`.
    static func getInAppStaticData(
        context: NSManagedObjectContext
    ) async -> (createdAt: Int64, bundle: InAppModel.InAppStaticProcess)? {
        do {
            return try await context.performAsync { () -> (
                createdAt: Int64, bundle: InAppModel.InAppStaticProcess
            )? in
                let request: NSFetchRequest<InAppStaticEntity> =
                InAppStaticEntity.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "createdAt", ascending: false)
                ]
                request.fetchLimit = 1

                guard
                    let entity = try context.fetch(request).first,
                    let inAppLibraryJs = entity.inAppLibraryJs,
                    let blockJs = entity.blockJs,
                    let blockCss = entity.blockCss
                else {
                    return nil
                }

                return (
                    createdAt: entity.createdAt,
                    bundle: InAppModel.InAppStaticProcess(
                        inAppLibraryJs: inAppLibraryJs,
                        blockJs: blockJs,
                        blockCss: blockCss
                    )
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Deletes all static In-App resources entries.
    ///
    /// Normally there should be only one row, but this clears all rows defensively.
    ///
    /// - Parameter context: Managed object context used for the operation.
    static func clearInAppStaticEntity(
        context: NSManagedObjectContext
    ) async {
        do {
            try await context.performAsync {
                let request: NSFetchRequest<InAppStaticEntity> = InAppStaticEntity.fetchRequest()
                let entities = try context.fetch(request)

                entities.forEach(context.delete)

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }
}
