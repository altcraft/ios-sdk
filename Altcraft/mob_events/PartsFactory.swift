//
//  PartsFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Represents a single multipart form-data section.
/// Used to build HTTP multipart requests.
///
/// Each `Part` contains metadata and raw data for upload.
///
/// - Parameters:
///   - name: Field name in the multipart form.
///   - data: Binary data content.
///   - mime: MIME type (e.g. `"text/plain"`, `"application/json"`).
///   - filename: Optional filename for file uploads.
struct Part {
    let name: String
    let data: Data
    let mime: String
    let filename: String?
}

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
private typealias ME = Constants.MobileEvents

enum PartsFactory {
    
    /// Builds multipart/form-data parts from `MobileEventData`.
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
    /// - Parameter event: Source DTO.
    /// - Returns: Immutable array of multipart parts.
    static func createMobileEventParts(from event: MobileEventData) -> [Part] {
        var parts: [Part] = []
        
        // Base fields (text)
        parts.append(makeTextPart(ME.TIME_ZONE, String(event.timeZone)))
        let tSec = epochSeconds(fromMillis: event.time) // ms -> sec
        parts.append(makeTextPart(ME.TIME_MOB, String(tSec)))
        parts.append(makeTextPart(ME.ALTCRAFT_CLIENT_ID, event.altcraftClientID ?? ""))
        parts.append(makeTextPart(ME.MOB_EVENT_NAME, event.eventName ?? ""))
        
        // matchingType (text)
        if let mt = event.matchingType, !mt.isEmpty {
            parts.append(makeTextPart(ME.MATCHING_TYPE, mt))
        }
        
        // UTM (text fields) — из Binary Data (JSON UTM) в entity/DTO
        if let utm = decodeUTM(event.utmTags) {
            if let v = utm.campaign, !v.isEmpty { parts.append(makeTextPart(ME.UTM_CAMPAIGN, v)) }
            if let v = utm.content,  !v.isEmpty { parts.append(makeTextPart(ME.UTM_CONTENT,  v)) }
            if let v = utm.keyword,  !v.isEmpty { parts.append(makeTextPart(ME.UTM_KEYWORD,  v)) }
            if let v = utm.medium,   !v.isEmpty { parts.append(makeTextPart(ME.UTM_MEDIUM,   v)) }
            if let v = utm.source,   !v.isEmpty { parts.append(makeTextPart(ME.UTM_SOURCE,   v)) }
            if let v = utm.temp,     !v.isEmpty { parts.append(makeTextPart(ME.UTM_TEMP,     v)) }
        }
        
        // Optional JSON blobs (already encoded as Data in MobileEventData)
        if let p = makeJsonPart(ME.PAYLOAD, event.payload) {
            parts.append(p)
        }
        
        if let smid = event.sendMessageId, !smid.isEmpty {
            // Send SMID as JSON string: "value"
            if let data = "\"\(smid)\"".data(using: .utf8),
               let p = makeJsonPart(ME.SMID_MOB, data) {
                parts.append(p)
            }
        }
        
        if let p = makeJsonPart(ME.MATCHING_MOB, event.matching) { parts.append(p) }
        if let p = makeJsonPart(ME.SUBSCRIPTION_MOB, event.subscription) { parts.append(p) }
        if let p = makeJsonPart(ME.PROFILE_FIELDS_MOB, event.profileFields) { parts.append(p) }
        
        return parts
    }
}
