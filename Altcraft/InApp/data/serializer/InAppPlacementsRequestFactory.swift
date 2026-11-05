//
//  InAppPlacementsRequestFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Creates a JSON body for an in-app placements request.
///
/// - Parameter data: The `InAppPlacesRequestData` containing
///   synchronization metadata and device identifiers.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createInAppPlacementsJSONBody(
    data: InAppPlacesRequestData
) -> Data? {
    let keys = InAppConstants.JSONKeys.self

    let json: [String: Any] = [
        keys.acid: data.acid,
        keys.deviceId: data.deviceId,
        keys.lastPublish: data.lastPublish,
        keys.placementRulesChecksum: data.placementRulesChecksum
    ]

    do {
        return try JSONSerialization.data(
            withJSONObject: json,
            options: []
        )
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for requesting in-app placement campaigns.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `InAppPlacesRequestData` containing
///   synchronization metadata and device identifiers.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func inAppPlacementsRequest(
    data: InAppPlacesRequestData
) async -> URLRequest? {
    guard let requestBody = createInAppPlacementsJSONBody(
        data: data
    ) else {
        return nil
    }

    return await CoreRequestBuilder.post(
        path: data.path,
        body: requestBody,
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
