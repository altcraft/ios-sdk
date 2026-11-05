//
//  InAppConfigDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData
@_spi(_Altcraft) import AltcraftCore

/// Data access object for the in-app module configuration.
///
/// Handles persistence and mapping between ``InAppConfiguration`` and
/// ``InAppConfigEntity``.
final class InAppConfigDao: @unchecked Sendable {

    /// Returns the stored in-app module configuration.
    ///
    /// Returns the default configuration when no stored configuration exists
    /// or the stored value cannot be read.
    func get() async -> InAppConfiguration {
        do {
            return try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppConfigEntity> =
                    InAppConfigEntity.fetchRequest()

                request.fetchLimit = 1

                guard let entity = try context.fetch(request).first else {
                    return InAppConfiguration()
                }

                return InAppConfiguration(
                    inAppAutoRequest: entity.inAppAutoRequest,
                    placementsRequestInterval: entity.placementsRequestInterval,
                    maxPlacements: Int(entity.maxPlacements)
                )
            }
        } catch {
            return InAppConfiguration()
        }
    }

    /// Persists the in-app module configuration.
    ///
    /// When the maximum placement limit changes, marks the limit as changed
    /// and resets the placement rules checksum to force a re-fetch.
    ///
    /// - Parameter config: In-app module configuration to persist.
    func set(_ config: InAppConfiguration) async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppConfigEntity> =
                    InAppConfigEntity.fetchRequest()

                request.fetchLimit = 1

                let found = try context.fetch(request).first

                let limitChanged = found.map {
                    Int($0.maxPlacements) != config.maxPlacements
                } ?? false

                let entity = found ?? InAppConfigEntity(context: context)

                entity.inAppAutoRequest = config.inAppAutoRequest
                entity.placementsRequestInterval = config.placementsRequestInterval
                entity.maxPlacements = Int32(config.maxPlacements)

                if limitChanged {
                    InAppPlacementCountManager.markMaxPlacementsChanged()

                    let stateRequest: NSFetchRequest<InAppsEntity> =
                        InAppsEntity.fetchRequest()

                    stateRequest.fetchLimit = 1

                    let state = try context.fetch(stateRequest).first
                    state?.placementRulesChecksum = ""
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Deletes the stored in-app module configuration.
    ///
    /// Delete errors are logged and swallowed inside the DAO.
    func delete() async {
        do {
            try await inAppDatabase.performBackgroundTask { context in
                let request: NSFetchRequest<InAppConfigEntity> =
                    InAppConfigEntity.fetchRequest()

                request.includesPropertyValues = false

                for entity in try context.fetch(request) {
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
}
