//
//  PartsFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Creates a plain text multipart section.
/// - Parameters:
///   - name: Part name.
///   - value: String value.
/// - Returns: A `Part` with MIME type `text/plain; charset=utf-8`.
@inline(__always)
private func makeTextPart(_ name: String, _ value: String) -> Part {
    Part(
        name: name,
        data: Data(value.utf8),
        mime: "text/plain; charset=utf-8",
        filename: nil
    )
}

/// Creates a JSON multipart section.
/// - Parameters:
///   - name: Part name.
///   - json: JSON data to include.
/// - Returns: A `Part` with MIME type `application/json; charset=utf-8`, or `nil` if data is `nil`.
@inline(__always)
private func makeJsonPart(_ name: String, _ json: Data?) -> Part? {
    guard let json else { return nil }
    return Part(
        name: name,
        data: json,
        mime: "application/json; charset=utf-8",
        filename: nil
    )
}

/// Safely converts epoch milliseconds to seconds (if already seconds, leaves as-is).
@inline(__always) private func epochSeconds(fromMillis ms: Int64) -> Int64 {
    ms >= 1_000_000_000_000 ? (ms / 1000) : ms
}

/// Short alias for verbose constants path
private typealias ME = TargetConstants.TargetEvents

/// Value snapshot of the `TargetEntity` fields used to build event parts.
///
/// Created on the owning context queue (see `init(entity:)`); contains only
/// plain values, so it is safe to pass across concurrency domains.
struct TargetEventSnapshot {
    let timeZone: Int16
    let time: Int64
    let altcraftClientID: String?
    let eventName: String?
    let matchingType: String?
    let utmTags: Data?
    let payload: Data?
    let sendMessageId: String?
    let matching: Data?
    let subscription: Data?
    let profileFields: Data?

    /// Reads entity fields on the caller's thread.
    ///
    /// Must be called on the entity's context queue (`perform` /
    /// `performAndWait`) or with the context confined to the caller.
    init(entity: TargetEntity) {
        timeZone = entity.timeZone
        time = entity.time
        altcraftClientID = entity.altcraftClientID
        eventName = entity.eventName
        matchingType = entity.matchingType
        utmTags = entity.utmTags
        payload = entity.payload
        sendMessageId = entity.sendMessageId
        matching = entity.matching
        subscription = entity.subscription
        profileFields = entity.profileFields
    }
}

/// Namespace for multipart part factories.
enum PartsFactory {

    /// Builds multipart/form-data parts from a `TargetEntity` (Core Data).
    ///
    /// Reads entity fields on the caller's thread — call only when the
    /// entity's context is owned by the caller (e.g. main-queue context in
    /// tests). The production path goes through `TargetEventSnapshot`.
    ///
    /// - Parameter event: Source Core Data entity.
    /// - Returns: Immutable array of multipart parts.
    static func createTargetEventParts(from event: TargetEntity) -> [Part] {
        createTargetEventParts(from: TargetEventSnapshot(entity: event))
    }

    /// Builds multipart/form-data parts from a `TargetEventSnapshot`.
    ///
    /// Required text fields:
    /// - `tz` (timezone offset minutes)
    /// - `t`  (event time in epoch seconds)
    /// - `aci` (Altcraft client ID)
    /// - `wn` (event name)
    ///
    /// Optional text fields:
    /// - `mm` (matchingType)
    /// - UTM: `cn`, `cc`, `ck`, `cm`, `cs`, `ct`
    ///
    /// Optional JSON parts (added when present):
    /// - `wd` (payload)
    /// - `mi` (sendMessageId as JSON string)
    /// - `ma` (matching)
    /// - `sn` (subscription)
    /// - `pf` (profile fields)
    ///
    /// - Parameter snapshot: Plain-value snapshot of the source entity.
    /// - Returns: Immutable array of multipart parts.
    static func createTargetEventParts(from snapshot: TargetEventSnapshot) -> [Part] {
        var parts: [Part] = []

        parts.append(makeTextPart(ME.TIME_ZONE, String(snapshot.timeZone)))
        let tSec = epochSeconds(fromMillis: snapshot.time)
        parts.append(makeTextPart(ME.TIME_MOB, String(tSec)))
        parts.append(makeTextPart(ME.ALTCRAFT_CLIENT_ID, snapshot.altcraftClientID ?? ""))
        parts.append(makeTextPart(ME.MOB_EVENT_NAME, snapshot.eventName ?? ""))

        if let mt = snapshot.matchingType, !mt.isEmpty {
            parts.append(makeTextPart(ME.MATCHING_TYPE, mt))
        }

        if let utm = decodeUTM(snapshot.utmTags) {
            if let v = utm.campaign, !v.isEmpty { parts.append(makeTextPart(ME.UTM_CAMPAIGN, v)) }
            if let v = utm.content,  !v.isEmpty { parts.append(makeTextPart(ME.UTM_CONTENT,  v)) }
            if let v = utm.keyword,  !v.isEmpty { parts.append(makeTextPart(ME.UTM_KEYWORD,  v)) }
            if let v = utm.medium,   !v.isEmpty { parts.append(makeTextPart(ME.UTM_MEDIUM,   v)) }
            if let v = utm.source,   !v.isEmpty { parts.append(makeTextPart(ME.UTM_SOURCE,   v)) }
            if let v = utm.temp,     !v.isEmpty { parts.append(makeTextPart(ME.UTM_TEMP,     v)) }
        }

        if let p = makeJsonPart(ME.PAYLOAD, snapshot.payload) {
            parts.append(p)
        }

        if let smid = snapshot.sendMessageId, !smid.isEmpty {
            if let data = "\"\(smid)\"".data(using: .utf8),
               let p = makeJsonPart(ME.SMID_MOB, data) {
                parts.append(p)
            }
        }

        if let p = makeJsonPart(ME.MATCHING_MOB, snapshot.matching) { parts.append(p) }
        if let p = makeJsonPart(ME.SUBSCRIPTION_MOB, snapshot.subscription) { parts.append(p) }
        if let p = makeJsonPart(ME.PROFILE_FIELDS_MOB, snapshot.profileFields) { parts.append(p) }

        return parts
    }
}
