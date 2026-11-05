//
//  StatusRequest.swift
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

    /// Represents the data required to request push subscription status.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - provider: Push provider identifier.
    ///   - token: Token associated with the provider.
    struct PushStatusRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let provider: String?
        let token: String?

        init(
            path: String,
            requestId: String,
            provider: String?,
            token: String?
        ) {
            self.path = path
            self.requestId = requestId
            self.provider = provider
            self.token = token
        }

        let requestName: String = PushConstants.RequestName.status
        let successEvent: any SDKEvent = PushModuleEvents.pushStatusRequestSuccessful
        let failedEvent: any SDKEvent = PushModuleEvents.pushStatusRequestFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { PushLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}

/// Creates a complete URL request for requesting push subscription status.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `PushStatusRequestData` containing status request parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func pushStatusRequest(
    data: RequestModel.PushStatusRequestData
) async -> URLRequest? {
    var queryItems: [URLQueryItem] = []
    if let provider = data.provider {
        queryItems.append(
            URLQueryItem(
                name: PushConstants.QueryItem.provider,
                value: provider
            )
        )
    }
    if let token = data.token {
        queryItems.append(
            URLQueryItem(
                name: PushConstants.QueryItem.subscriptionId,
                value: token
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
