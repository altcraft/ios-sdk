//
//  InAppPlacementCountManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles in-app placement count limits and their changes.
///
/// Mirrors Android `PlacementCountManager`: trims received placements to the
/// configured maximum (keeping the latest, i.e. largest `companyId`s) and flags
/// when the configured limit changes so the placements re-fetch is forced.
@available(iOSApplicationExtension, unavailable)
final class InAppPlacementCountManager: @unchecked Sendable {

    private static let lock = NSLock()
    private nonisolated(unsafe) static var flag = false

    private init() {}

    /// Indicates whether the maximum placement limit has changed since the
    /// previous placements request.
    static func isMaxPlacementsChanged() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return flag
    }

    /// Marks the maximum placement limit as changed, forcing a re-fetch.
    static func markMaxPlacementsChanged() {
        lock.lock()
        defer { lock.unlock() }
        flag = true
    }

    /// Clears the changed flag after a placements request has been processed.
    static func resetMaxPlacementsChanged() {
        lock.lock()
        defer { lock.unlock() }
        flag = false
    }

    /// Trims in-app placements to the configured maximum.
    ///
    /// When the limit is exceeded, placements with the largest `companyId` are
    /// kept and an event containing the rejected company identifiers is emitted.
    ///
    /// - Parameters:
    ///   - items: Received in-app placements.
    ///   - max: Maximum number of placements to keep.
    /// - Returns: At most `max` in-app placements.
    @discardableResult
    static func trimToMax(
        _ items: [InAppModel.InApp],
        max: Int
    ) -> [InAppModel.InApp] {
        guard items.count > max else {
            return items
        }

        guard max >= 1 else {
            return []
        }

        let sorted = items.sorted { $0.companyId > $1.companyId }
        let rejectedCompanyIds = sorted
            .dropFirst(max)
            .map { $0.companyId }

        if !rejectedCompanyIds.isEmpty {
            let value: [String: Any?] = [
                InAppConstants.PlacementsEventKeys.rejectedCompanyIds: rejectedCompanyIds,
                InAppConstants.PlacementsEventKeys.received: items.count,
                InAppConstants.PlacementsEventKeys.limit: max
            ]

            InAppLog.event(
                "inAppPlacements",
                event: InAppModuleEvents.placementsLimitExceeded,
                eventValue: value,
                logValue: ResponseModel.OrderedLogValue(value)
            )
        }

        return Array(sorted.prefix(max))
    }
}
