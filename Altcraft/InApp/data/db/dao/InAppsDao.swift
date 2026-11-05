//
//  InAppsDao.swift
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

/// Value snapshot of the stored in-app synchronization entity.
///
/// Fields are read on the context's queue; the snapshot contains only plain
/// values, so it is safe to pass across concurrency domains. Optionality of
/// string fields is preserved to keep downstream fallback semantics intact.
struct InAppsStateSnapshot {
    let acid: String?
    let deviceId: String?
    let lastRequestTime: Int64
    let lastPublish: Int64
    let placementRulesChecksum: String?
}

/// Data-access operations for in-app data.
enum InAppsDAO {

    /// Inserts or replaces an `InAppsEntity` in Core Data.
    ///
    /// Entity can contain only one record, so previous data is reused if it exists.
    ///
    /// - Parameters:
    ///   - acid: Altcraft identifier.
    ///   - lastRequestTime: Last request timestamp.
    ///   - deviceId: Device identifier.
    ///   - lastPublish: Last publish timestamp.
    ///   - placementRulesChecksum: Placement rules checksum.
    /// - Returns: `.success(())` on success, `.failure(error)` on failure.
    static func setInAppsEntity(
        acid: String,
        lastRequestTime: Int64,
        deviceId: String,
        lastPublish: Int64,
        placementRulesChecksum: String
    ) async -> Result<Void, Error> {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppsEntity> = InAppsEntity.fetchRequest()
                request.fetchLimit = 1

                let entity = try context.fetch(request).first ?? InAppsEntity(context: context)

                entity.acid = acid
                entity.lastRequestTime = lastRequestTime
                entity.deviceId = deviceId
                entity.lastPublish = lastPublish
                entity.placementRulesChecksum = placementRulesChecksum

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

    /// Deletes stored `InAppsEntity` record.
    ///
    /// Important:
    /// This method intentionally does not use `NSBatchDeleteRequest`.
    /// Some Core Data stores do not support batch delete requests and can throw
    /// an Objective-C exception, which Swift `do/catch` cannot catch.
    static func clearInAppsData() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppsEntity> = InAppsEntity.fetchRequest()
                request.includesPropertyValues = false

                let entities = try context.fetch(request)

                for entity in entities {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Returns a snapshot of the stored in-app synchronization state.
    ///
    /// Fields are read on the context's queue.
    ///
    /// - Parameter context: The Core Data context to perform the fetch in.
    /// - Returns: Stored state snapshot, or `nil` if it does not exist.
    static func getInAppsState(
        context: NSManagedObjectContext
    ) async -> InAppsStateSnapshot? {
        do {
            return try await context.performAsync {
                let request: NSFetchRequest<InAppsEntity> = InAppsEntity.fetchRequest()
                request.fetchLimit = 1

                guard let entity = try context.fetch(request).first else {
                    return nil
                }

                return InAppsStateSnapshot(
                    acid: entity.acid,
                    deviceId: entity.deviceId,
                    lastRequestTime: entity.lastRequestTime,
                    lastPublish: entity.lastPublish,
                    placementRulesChecksum: entity.placementRulesChecksum
                )
            }
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

}
