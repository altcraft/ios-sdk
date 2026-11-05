//
//  UpdateRequest.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Converts a Boolean value to its query parameter representation.
private func toQueryValue(_ value: Bool) -> String { value ? "1" : "0" }

extension RequestModel {

    /// Represents the data required to update a push token.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - oldToken: Previous token value, if available.
    ///   - newToken: New token value to register.
    ///   - oldProvider: Previous token provider, if available.
    ///   - newProvider: New token provider.
    ///   - sync: If `true`, executes the request synchronously.
    struct TokenUpdateRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let oldToken: String?
        let newToken: String
        let oldProvider: String?
        let newProvider: String
        let sync: Bool

        init(
            path: String,
            requestId: String,
            oldToken: String?,
            newToken: String,
            oldProvider: String?,
            newProvider: String,
            sync: Bool
        ) {
            self.path = path
            self.requestId = requestId
            self.oldToken = oldToken
            self.newToken = newToken
            self.oldProvider = oldProvider
            self.newProvider = newProvider
            self.sync = sync
        }

        let requestName: String = PushConstants.RequestName.tokenUpdate
        let successEvent: any SDKEvent = PushModuleEvents.tokenUpdateRequestSuccessful
        let failedEvent: any SDKEvent = PushModuleEvents.tokenUpdateRequestFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { PushLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}

/// Creates a JSON body for the push token update request.
///
/// - Parameter data: The `TokenUpdateRequestData` containing token details.
/// - Returns: JSON-encoded `Data`, or `nil` if encoding fails.
func createUpdateJSONBody(
    data: RequestModel.TokenUpdateRequestData
) -> Data? {
    let keys = PushConstants.JSONKeys.self

    let json: [String: Any] = [
        keys.oldToken: data.oldToken ?? NSNull(),
        keys.oldProvider: data.oldProvider ?? NSNull(),
        keys.newToken: data.newToken,
        keys.newProvider: data.newProvider
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for updating a push token.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `TokenUpdateRequestData` containing token update info.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func tokenUpdateRequest(
    data: RequestModel.TokenUpdateRequestData
) async -> URLRequest? {
    guard let requestBody = createUpdateJSONBody(
        data: data
    ) else {
        return nil
    }

    var queryItems: [URLQueryItem] = [
        URLQueryItem(
            name: PushConstants.QueryItem.provider,
            value: data.newProvider
        ),
        URLQueryItem(
            name: PushConstants.QueryItem.sync,
            value: toQueryValue(data.sync)
        )
    ]
    if let oldToken = data.oldToken {
        queryItems.append(
            URLQueryItem(
                name: PushConstants.QueryItem.subscriptionId,
                value: oldToken
            )
        )
    }

    return await CoreRequestBuilder.post(
        path: data.path,
        body: requestBody,
        queryItems: queryItems,
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
