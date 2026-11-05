//
//  InAppRequestData.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Represents the data required to request in-app placement campaigns.
///
/// - Properties:
///   - path: Relative API endpoint path.
///   - requestId: Unique request ID.
///   - acid: Profile ACID value.
///   - deviceId: Device ID as UUIDv4 string.
///   - lastPublish: Last known in-app publish timestamp.
///   - placementRulesChecksum: Last known placement rules checksum.
struct InAppPlacesRequestData: RequestModel.RequestData {
    typealias Response = InAppPlacesResponse

    let path: String
    let requestId: String
    let acid: String
    let deviceId: String
    let lastPublish: Int64
    let placementRulesChecksum: String

    let requestName: String = InAppConstants.RequestName.placements
    let successEvent: any SDKEvent = InAppModuleEvents.inAppPlacementsRequestSuccessful
    let failedEvent: any SDKEvent = InAppModuleEvents.inAppPlacementsRequestFailed
    let eventData: [String: Any?]? = nil
    let logData: [String: Any?]? = nil

    var moduleLogPrefix: String { InAppLog.MODULE_PREFIX }

    var responseType: Response.Type {
        Response.self
    }
}
