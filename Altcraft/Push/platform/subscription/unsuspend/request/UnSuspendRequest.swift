//
//  UnSuspendRequest.swift
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

    /// Represents the data required to send an unsuspend request.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - provider: Push notification provider name.
    ///   - token: Device push token.
    struct UnSuspendRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let provider: String
        let token: String

        init(
            path: String,
            requestId: String,
            provider: String,
            token: String
        ) {
            self.path = path
            self.requestId = requestId
            self.provider = provider
            self.token = token
        }

        let requestName: String = PushConstants.RequestName.unsuspend
        let successEvent: any SDKEvent = PushModuleEvents.unsuspendRequestSuccessful
        let failedEvent: any SDKEvent = PushModuleEvents.unsuspendRequestFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { PushLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}

/// Creates a JSON body for the unsuspend request.
///
/// - Parameter data: The `UnSuspendRequestData` containing subscription identifiers.
/// - Returns: JSON-encoded `Data`, or `nil` on failure.
func createUnSuspendJSONBody(
    data: RequestModel.UnSuspendRequestData
) -> Data? {
    let keys = PushConstants.JSONKeys.self

    let json: [String: Any] = [
        keys.subscription: [
            keys.subscriptionId: data.token,
            keys.provider: data.provider
        ],
        keys.replace: true
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for the unsuspend operation.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `UnSuspendRequestData` containing request configuration and authentication.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func unSuspendRequest(
    data: RequestModel.UnSuspendRequestData
) async -> URLRequest? {
    guard let requestBody = createUnSuspendJSONBody(
        data: data
    ) else {
        return nil
    }

    return await CoreRequestBuilder.post(
        path: data.path,
        body: requestBody,
        queryItems: [
            URLQueryItem(
                name: PushConstants.QueryItem.provider,
                value: data.provider
            ),
            URLQueryItem(
                name: PushConstants.QueryItem.subscriptionId,
                value: data.token
            )
        ],
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
