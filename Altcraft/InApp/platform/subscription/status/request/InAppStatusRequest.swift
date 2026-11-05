//
//  InAppStatusRequest.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

extension RequestModel {

    /// Represents the data required to request in-app subscription status.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - deviceId: Device ID as UUIDv4 string.
    struct InAppStatusRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let deviceId: String?

        init(
            path: String,
            requestId: String,
            deviceId: String?
        ) {
            self.path = path
            self.requestId = requestId
            self.deviceId = deviceId
        }

        let requestName: String = InAppConstants.RequestName.status
        let successEvent: any SDKEvent = InAppModuleEvents.inAppStatusRequestSuccessful
        let failedEvent: any SDKEvent = InAppModuleEvents.inAppStatusRequestFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { InAppLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}

/// Creates a complete URL request for requesting in-app subscription status.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `InAppStatusRequestData` containing status request parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func inAppStatusRequest(
    data: RequestModel.InAppStatusRequestData
) async -> URLRequest? {
    var queryItems: [URLQueryItem] = []
    if let deviceId = data.deviceId {
        queryItems.append(
            URLQueryItem(
                name: InAppConstants.QueryItem.subscriptionId,
                value: deviceId
            )
        )
    }

    return await CoreRequestBuilder.get(
        path: data.path,
        queryItems: queryItems.isEmpty ? nil : queryItems,
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
