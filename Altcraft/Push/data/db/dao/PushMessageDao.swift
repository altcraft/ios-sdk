//
//  PushMessageDao.swift
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

/// Data-access operations for processed push message UIDs and their event
/// send statuses.
///
/// Each message UID is stored once, together with two flags that mark whether
/// the `"delivery"` and `"open"` push events have already been created for it.
/// Only the latest `PushConstants.Dedup.maxStoredUIDs` records are kept, so a
/// message that returns after a long period is treated as unseen again.
enum PushMessageDAO {

    /// Claims the delivery event of the message UID.
    ///
    /// - Parameter uid: The unique identifier of the incoming push message.
    /// - Returns: `true` if the delivery event should be sent (first claim),
    ///   otherwise `false`.
    static func shouldSendDeliveryEvent(uid: String) async -> Bool {
        await claimEvent(uid: uid, event: .delivery)
    }

    /// Claims the open event of the message UID.
    ///
    /// - Parameter uid: The unique identifier of the opened push message.
    /// - Returns: `true` if the open event should be sent (first claim),
    ///   otherwise `false`.
    static func shouldSendOpenEvent(uid: String) async -> Bool {
        await claimEvent(uid: uid, event: .open)
    }

    /// Claims a push event of the message UID by marking its send status.
    ///
    /// The status check, the record creation and the trim run as a single
    /// background context save. The `uid` attribute carries a Core Data
    /// uniqueness constraint, so a concurrent claim of the same UID fails to
    /// save and is reported as a duplicate — matching the atomic
    /// `INSERT OR IGNORE` semantics of the Android implementation even when
    /// the notification service extension processes pushes in parallel.
    ///
    /// - Parameters:
    ///   - uid: The unique identifier of the push message.
    ///   - event: The event type to claim.
    /// - Returns: `true` if the event should be sent, otherwise `false`.
    private static func claimEvent(
        uid: String,
        event: ClaimedEvent
    ) async -> Bool {
        do {
            return try await pushDatabase.performBackgroundTask { context in
                let stored = try context.fetch(PushMessageEntity.fetchRequest())

                let records: [PushMessageEntity]
                let entity: PushMessageEntity

                if let existing = stored.first(where: { $0.uid == uid }) {
                    entity = existing
                    records = stored
                } else {
                    entity = PushMessageEntity(context: context)
                    entity.uid = uid
                    // Insertion-order stamp (Android rowid analogue): strictly
                    // monotonic, so the newest record is always the last insert.
                    entity.time = max(
                        Int64(Date().timeIntervalSince1970 * 1000),
                        (stored.map(\.time).max() ?? 0) + 1
                    )
                    entity.deliverySent = false
                    entity.openSent = false
                    records = stored + [entity]
                }

                switch event {
                case .delivery:
                    if entity.deliverySent { return false }
                    entity.deliverySent = true
                case .open:
                    if entity.openSent { return false }
                    entity.openSent = true
                }

                // Keep only the latest UIDs, dropping the oldest ones.
                let overflow = records.count - PushConstants.Dedup.maxStoredUIDs
                if overflow > 0 {
                    records
                        .sorted { $0.time < $1.time }
                        .prefix(overflow)
                        .forEach(context.delete)
                }

                // Any save failure — a uniqueness violation from a concurrent
                // context above all — means the event is already claimed.
                context.mergePolicy = NSMergePolicy(merge: .errorMergePolicyType)
                try context.save()
                return true
            }
        } catch {
            PushLog.error(#function, error: error)
            return false
        }
    }
}

/// The push event type claimed for a message UID.
private enum ClaimedEvent {

    /// The `"delivery"` push event.
    case delivery

    /// The `"open"` push event.
    case open
}
