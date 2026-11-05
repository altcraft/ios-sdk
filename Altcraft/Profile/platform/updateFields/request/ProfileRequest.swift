//
//  ProfileRequest.swift
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

    /// Represents the data required to update profile fields.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - profileFields: Profile fields payload.
    ///   - skipTriggers: If `true`, skips trigger execution.
    internal struct ProfileUpdateRequestData: RequestData {
        typealias Response = ResponseModel.AsyncResponse

        let path: String
        let requestId: String
        let profileFields: [String: Any]?
        let skipTriggers: Bool?

        init(
            path: String,
            requestId: String,
            profileFields: [String: Any]?,
            skipTriggers: Bool?
        ) {
            self.path = path
            self.requestId = requestId
            self.profileFields = profileFields
            self.skipTriggers = skipTriggers
        }

        let requestName: String = ProfileConstants.RequestName.update
        let successEvent: any SDKEvent = ProfileModuleEvents.profileUpdateRequestSuccessful
        let failedEvent: any SDKEvent = ProfileModuleEvents.profileUpdateRequestFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { ProfileLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}

/// Creates a JSON body for the profile update request.
///
/// - Parameter data: The `ProfileUpdateRequestData` containing profile fields and options.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createProfileUpdateJSONBody(
    data: RequestModel.ProfileUpdateRequestData
) -> Data? {
    let keys = ProfileConstants.JSONKeys.self

    let json: [String: Any] = [
        keys.profileFields: data.profileFields ?? NSNull(),
        keys.skipTriggers: data.skipTriggers ?? NSNull()
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        ProfileLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for updating profile fields.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `ProfileUpdateRequestData` containing profile update parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func profileUpdateRequest(
    data: RequestModel.ProfileUpdateRequestData
) async -> URLRequest? {
    guard let requestBody = createProfileUpdateJSONBody(
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
