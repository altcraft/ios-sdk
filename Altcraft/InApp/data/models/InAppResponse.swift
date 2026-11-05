//
//  InAppResponse.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Response containing in-app campaigns and their placement settings.
///
/// Raw campaigns and placement options are returned as separate lists.
///
/// Regular campaigns are joined by campaign id with placement settings
/// and mapped to runtime `InAppModel.InApp` models.
///
/// Test campaigns are not persisted and are converted directly
/// into runtime `InAppModel.InApp` models.
///
/// The response also exposes all received campaign `smid` values
/// through `eventData` under the `all_smid` key.
///
/// - Parameters:
///   - error: Response error code.
///   - errorText: Response error message.
///   - lastPublish: Last in-app publish timestamp.
///   - checksum: Placement rules checksum.
///   - rawInApps: Raw in-app campaigns.
///   - rawPlacements: Raw placement settings.
struct InAppPlacesResponse: Codable, ResponseModel.BaseResponseData, Sendable {
    let error: Int?
    let errorText: String?
    let lastPublish: Int64
    let checksum: String

    private let rawInApps: [InAppModel.RawInApp]
    private let rawPlacements: [InAppModel.RawPlacement]

    /// JSON coding keys for the parent model.
    enum CodingKeys: String, CodingKey {
        case error
        case errorText = "error_text"
        case lastPublish = "last_publish"
        case checksum = "placement_rules_checksum"
        case rawInApps = "inapps"
        case rawPlacements = "placements"
    }

    init(
        error: Int? = nil,
        errorText: String? = nil,
        lastPublish: Int64 = 0,
        checksum: String = "",
        rawInApps: [InAppModel.RawInApp] = [],
        rawPlacements: [InAppModel.RawPlacement] = []
    ) {
        self.error = error
        self.errorText = errorText
        self.lastPublish = lastPublish
        self.checksum = checksum
        self.rawInApps = rawInApps
        self.rawPlacements = rawPlacements
    }

    /// Additional data used as SDK event value payload.
    ///
    /// Includes base response fields and all received in-app campaign
    /// message identifiers.
    var eventData: [String: Any?] {
        [
            ResponseModel.errorKey: error,
            ResponseModel.errorTextKey: errorText,
            InAppConstants.MapKeys.allSmidKey: rawInApps.map { $0.smid }
        ]
    }

    /// Additional data used as SDK log payload.
    var logData: [String: Any?]? {
        [
            ResponseModel.errorKey: error,
            ResponseModel.errorTextKey: errorText
        ]
    }

    /// Regular in-app campaigns mapped to runtime models.
    ///
    /// Only campaigns where `is_test != true` are returned.
    ///
        /// Raw campaigns are joined with placement settings by campaign id.
        /// Items without matching placement settings are skipped.
        ///
        /// Duplicate placement ids are tolerated (Android `associateBy`
        /// parity): the last placement with a given id wins.
        var inApps: [InAppModel.InApp] {
            let placementsById = Dictionary(
                rawPlacements.map { ($0.id, $0) },
                uniquingKeysWith: { _, last in last }
            )

        return rawInApps.compactMap { rawInApp in
            guard rawInApp.isTest != true else { return nil }
            guard let companyId = rawInApp.companyId else { return nil }
            guard let rawPlacement = placementsById[companyId] else { return nil }

            return InAppMapper.toInApp(
                rawInApp: rawInApp,
                rawPlacement: rawPlacement
            )
        }
    }

    /// Test in-app campaigns converted directly to runtime models.
    ///
    /// Test campaigns are selected by `is_test == true`.
    /// They do not require placement settings and are not saved to storage.
    ///
    /// Missing placement-related fields are replaced with default values
    /// inside `InAppMapper.rawToTestInApp`.
    var testInApps: [InAppModel.InApp] {
        rawInApps
            .filter { $0.isTest == true }
            .map { rawInApp in
                InAppMapper.rawToTestInApp(rawInApp)
            }
    }

    /// Creates in-app synchronization state
    /// from response metadata and current request context.
    ///
    /// - Parameters:
    ///   - acid: Altcraft identifier.
    ///   - deviceId: Device identifier.
    ///   - lastRequestTime: Last request timestamp.
    /// - Returns: In-app synchronization state.
    func toState(
        acid: String,
        deviceId: String,
        lastRequestTime: Int64
    ) -> InAppModel.InAppsState {
        InAppModel.InAppsState(
            acid: acid,
            deviceId: deviceId,
            lastRequestTime: lastRequestTime,
            lastPublish: lastPublish,
            placementRulesChecksum: checksum
        )
    }
}
