//
//  TargetRequest.swift
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

    /// Represents the data required to send a mobile event.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - sid: Pixel string identifier.
    ///   - name: Event name.
    ///   - parts: Multipart body parts.
    internal struct TargetEventRequestData: RequestData {
        typealias Response = ResponseModel.AsyncResponse

        let path: String
        let requestId: String
        let sid: String
        let name: String
        let parts: [Part]

        init(
            path: String,
            requestId: String,
            sid: String,
            name: String,
            parts: [Part]
        ) {
            self.path = path
            self.requestId = requestId
            self.sid = sid
            self.name = name
            self.parts = parts
        }

        let requestName: String = TargetConstants.RequestName.event
        let successEvent: any SDKEvent = TargetModuleEvents.mobileEventRequestSuccessful
        let failedEvent: any SDKEvent = TargetModuleEvents.mobileEventRequestFailed

        var responseType: Response.Type {
            Response.self
        }

        var eventData: [String: Any?]? {
            [
                TargetConstants.MapKeys.name: name
            ]
        }

        var logData: [String: Any?]? {
            [
                TargetConstants.MapKeys.name: name
            ]
        }

        var moduleLogPrefix: String { TargetLog.MODULE_PREFIX }
    }
}

/// Creates a complete URL request for sending a mobile event.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `TargetEventRequestData` containing event parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func mobileEventRequest(
    data: RequestModel.TargetEventRequestData
) async -> URLRequest? {
    let boundary = makeBoundary()
    let body = buildMultipartBody(parts: data.parts, boundary: boundary)

    return await CoreRequestBuilder.multipartPost(
        path: data.path,
        body: body,
        boundary: boundary,
        queryItems: [
            URLQueryItem(
                name: TargetConstants.WebEventQuery.pixelIDKey,
                value: data.sid
            ),
            URLQueryItem(
                name: TargetConstants.WebEventQuery.trackerKey,
                value: TargetConstants.WebEventQuery.trackerValue
            ),
            URLQueryItem(
                name: TargetConstants.WebEventQuery.typeKey,
                value: TargetConstants.WebEventQuery.typeValue
            ),
            URLQueryItem(
                name: TargetConstants.WebEventQuery.versionKey,
                value: TargetConstants.WebEventQuery.versionValue
            )
        ],
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
