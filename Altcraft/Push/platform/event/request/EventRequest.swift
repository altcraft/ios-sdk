//
//  EventRequest.swift
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

    /// Represents the data required to send a push event.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - time: Event timestamp in epoch milliseconds.
    ///   - type: Push event type, for example `"delivery"` or `"open"`.
    ///   - uid: Unique notification identifier.
    struct PushEventRequestData: RequestData {
        typealias Response = ResponseModel.AsyncResponse

        let path: String
        let requestId: String
        let time: Int64
        let type: String
        let uid: String

        init(
            path: String,
            requestId: String,
            time: Int64,
            type: String,
            uid: String
        ) {
            self.path = path
            self.requestId = requestId
            self.time = time
            self.type = type
            self.uid = uid
        }

        let requestName: String = PushConstants.RequestName.pushEvent
        let successEvent: any SDKEvent = PushModuleEvents.pushEventRequestSuccessful
        let failedEvent: any SDKEvent = PushModuleEvents.pushEventRequestFailed

        var responseType: Response.Type {
            Response.self
        }

        var eventData: [String: Any?]? {
            [
                PushConstants.MapKeys.uid: uid,
                PushConstants.MapKeys.type: type
            ]
        }

        var logData: [String: Any?]? {
            [
                PushConstants.MapKeys.type: type
            ]
        }

        var moduleLogPrefix: String { PushLog.MODULE_PREFIX }

        var isValid: Bool {
            let allowedTypes = [
                PushConstants.PushEvents.delivery,
                PushConstants.PushEvents.open
            ]

            return time > 0 &&
            !uid.isEmpty &&
            allowedTypes.contains(type)
        }
    }
}

/// Creates a JSON body for a push event request.
///
/// - Parameter data: The `PushEventRequestData` containing event time and UID.
/// - Returns: JSON-encoded `Data`, or `nil` if encoding fails.
func createPushEventJSONBody(
    data: RequestModel.PushEventRequestData
) -> Data? {
    let keys = PushConstants.JSONKeys.self

    let json: [String: Any] = [
        keys.time: data.time,
        keys.smid: data.uid
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for sending a push event.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `PushEventRequestData` containing event metadata.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func pushEventRequest(
    data: RequestModel.PushEventRequestData
) async -> URLRequest? {
    guard let requestBody = createPushEventJSONBody(
        data: data
    ) else {
        return nil
    }

    return await CoreRequestBuilder.post(
        path: "\(data.path)/\(data.type)",
        body: requestBody,
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
