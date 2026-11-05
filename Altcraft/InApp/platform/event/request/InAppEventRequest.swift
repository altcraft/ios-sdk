//
//  InAppEventRequest.swift
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

    /// Represents the payload for an in-app event.
    ///
    /// - Properties:
    ///   - name: Clicked element name.
    ///   - href: Clicked element link URL.
    ///   - code: Error code.
    ///   - message: Error message.
    struct InAppEventData: Codable, Sendable {
        let name: String?
        let href: String?
        let code: Int?
        let message: String?

        init(
            name: String? = nil,
            href: String? = nil,
            code: Int? = nil,
            message: String? = nil
        ) {
            self.name = name
            self.href = href
            self.code = code
            self.message = message
        }
    }

    /// Represents the data required to send an in-app event.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - type: In-app event type.
    ///   - time: Event time in Unix milliseconds.
    ///   - smid: Send Message ID.
    ///   - acid: Altcraft Client ID.
    ///   - data: Optional event payload for `click` and `error` events.
    struct InAppEventRequestData: RequestData {
        typealias Response = ResponseModel.AsyncResponse

        let path: String
        let requestId: String
        let type: String
        let time: Int64
        let smid: String
        let acid: String
        let data: InAppEventData?

        init(
            path: String,
            requestId: String,
            type: String,
            time: Int64,
            smid: String,
            acid: String,
            data: InAppEventData?
        ) {
            self.path = path
            self.requestId = requestId
            self.type = type
            self.time = time
            self.smid = smid
            self.acid = acid
            self.data = data
        }

        let requestName: String = InAppConstants.RequestName.event
        let successEvent: any SDKEvent = InAppModuleEvents.inAppEventRequestSuccessful
        let failedEvent: any SDKEvent = InAppModuleEvents.inAppEventRequestFailed

        var responseType: Response.Type {
            Response.self
        }

        var eventData: [String: Any?]? {
            [
                InAppConstants.MapKeys.smid: smid,
                InAppConstants.MapKeys.type: type
            ]
        }

        var logData: [String: Any?]? {
            [
                InAppConstants.MapKeys.type: type
            ]
        }

        var moduleLogPrefix: String { InAppLog.MODULE_PREFIX }
    }
}

/// Creates a JSON body for an in-app event request.
///
/// Event payload mapping:
/// - delivery -> no extra payload
/// - show -> no extra payload
/// - click -> `{ "name": "...", "link": "..." }`
/// - error -> `{ "code": "...", "message": "..." }`
/// - close -> no extra payload
///
/// - Parameter data: The `InAppEventRequestData` containing
///   event metadata and optional payload.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createInAppEventJSONBody(
    data: RequestModel.InAppEventRequestData
) -> Data? {
    let keys = InAppConstants.JSONKeys.self

    var json: [String: Any] = [
        keys.time: data.time,
        keys.smid: data.smid,
        keys.acid: data.acid
    ]

    if let payload = data.data {
        var payloadData: [String: Any] = [:]

        if let name = payload.name {
            payloadData[keys.name] = name
        }

        if let href = payload.href {
            payloadData[keys.link] = href
        }

        if let code = payload.code {
            payloadData[keys.code] = code
        }

        if let message = payload.message {
            payloadData[keys.message] = message
        }

        if !payloadData.isEmpty {
            json[keys.data] = payloadData
        }
    }

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for sending an in-app event.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `InAppEventRequestData` containing event parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func inAppEventRequest(
    data: RequestModel.InAppEventRequestData
) async -> URLRequest? {
    guard let requestBody = createInAppEventJSONBody(
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

/// Encodes optional in-app event payload into JSON data.
///
/// - Parameter data: Optional in-app event payload.
/// - Returns: Serialized JSON data or `nil`.
func encodeInAppEventData(
    _ data: RequestModel.InAppEventData?
) -> Data? {
    guard let data else {
        return nil
    }

    do {
        return try JSONEncoder().encode(data)
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Decodes stored in-app event payload from JSON data.
///
/// - Parameter data: Serialized in-app event payload.
/// - Returns: Decoded in-app event payload, or `nil` if data is missing or invalid.
func decodeInAppEventData(
    _ data: Data?
) -> RequestModel.InAppEventData? {
    guard let data else {
        return nil
    }

    do {
        return try JSONDecoder().decode(
            RequestModel.InAppEventData.self,
            from: data
        )
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}
