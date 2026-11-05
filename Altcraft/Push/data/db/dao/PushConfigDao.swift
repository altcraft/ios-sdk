//
//  PushConfigDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData
@_spi(_Altcraft) import AltcraftCore

/// Data access object for the push module configuration.
///
/// Handles persistence and mapping between ``PushConfiguration`` and
/// ``PushConfigEntity``.
final class PushConfigDao: @unchecked Sendable {

    /// Returns the stored push module configuration.
    ///
    /// Returns a configuration with an empty provider priority when no stored
    /// configuration exists or the stored value cannot be read.
    func get() async -> PushConfiguration {
        do {
            return try await pushDatabase.performBackgroundTask { context in
                let request = PushConfigEntity.fetchRequest()
                request.fetchLimit = 1

                let entity = try context.fetch(request).first

                let priority = entity.flatMap {
                    decodeList(from: $0.providerPriority)
                } ?? []

                return PushConfiguration(
                    providerPriority: priority
                )
            }
        } catch {
            return PushConfiguration(
                providerPriority: []
            )
        }
    }

    /// Persists the push module configuration.
    ///
    /// Save errors are logged and swallowed inside the DAO.
    ///
    /// - Parameter config: Push module configuration to persist.
    func set(_ config: PushConfiguration) async {
        do {
            try await pushDatabase.performBackgroundTask { context in
                let request = PushConfigEntity.fetchRequest()
                request.fetchLimit = 1

                let entity = try context.fetch(request).first
                    ?? PushConfigEntity(context: context)

                entity.providerPriority = encodeList(
                    config.providerPriority
                )

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            PushLog.error(
                #function,
                error: PushModuleEvents.pushConfigurationSaveFailed
            )
        }
    }

    /// Deletes the stored push module configuration.
    ///
    /// Delete errors are logged and swallowed inside the DAO.
    func delete() async {
        do {
            try await pushDatabase.performBackgroundTask { context in
                let request = PushConfigEntity.fetchRequest()
                request.includesPropertyValues = false

                for entity in try context.fetch(request) {
                    context.delete(entity)
                }

                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {
            PushLog.error(
                #function,
                error: PushModuleEvents.pushConfigurationClearFailed
            )
        }
    }
}
