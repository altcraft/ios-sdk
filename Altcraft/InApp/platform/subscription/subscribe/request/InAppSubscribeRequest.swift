//
//  InAppSubscribeRequest.swift
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

    /// Represents the data required to create an in-app subscription request.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - time: Request timestamp in epoch milliseconds.
    ///   - deviceId: Device ID as UUIDv4 string.
    ///   - acid: Profile ACID value.
    ///   - status: Subscription status.
    ///   - sync: Request execution mode:
    ///     - `true` — synchronous mode, the server returns the final result.
    ///     - `false` — asynchronous mode, the server returns acceptance or queue status only.
    ///   - profileFields: Profile fields payload.
    ///   - fields: Extra subscription fields payload.
    ///   - cats: Category list payload.
    ///   - replace: If `true`, replaces an existing subscription.
    ///   - skipTriggers: If `true`, skips trigger execution.
    struct InAppSubscribeRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let time: Int64
        let deviceId: String
        let acid: String
        let status: String
        let sync: Bool
        let profileFields: [String: Any]?
        let fields: [String: Any]?
        let cats: [CategoryData]?
        let replace: Bool?
        let skipTriggers: Bool?

        init(
            path: String,
            requestId: String,
            time: Int64,
            deviceId: String,
            acid: String,
            status: String,
            sync: Bool,
            profileFields: [String: Any]?,
            fields: [String: Any]?,
            cats: [CategoryData]?,
            replace: Bool?,
            skipTriggers: Bool?
        ) {
            self.path = path
            self.requestId = requestId
            self.time = time
            self.deviceId = deviceId
            self.acid = acid
            self.status = status
            self.sync = sync
            self.profileFields = profileFields
            self.fields = fields
            self.cats = cats
            self.replace = replace
            self.skipTriggers = skipTriggers
        }

        var requestName: String {
            switch status {
            case InAppConstants.SubStatus.subscribed:
                return InAppConstants.RequestName.subscribe
            default:
                return InAppConstants.RequestName.unsubscribe
            }
        }

        var successEvent: any SDKEvent {
            switch status {
            case InAppConstants.SubStatus.subscribed:
                return InAppModuleEvents.inAppSubscribeRequestSuccessful
            default:
                return InAppModuleEvents.inAppUnsubscribeRequestSuccessful
            }
        }

        var failedEvent: any SDKEvent {
            switch status {
            case InAppConstants.SubStatus.subscribed:
                return InAppModuleEvents.inAppSubscribeRequestFailed
            default:
                return InAppModuleEvents.inAppUnsubscribeRequestFailed
            }
        }

        var responseType: Response.Type {
            Response.self
        }

        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { InAppLog.MODULE_PREFIX }

        var isValid: Bool {
            time > 0 &&
            !requestId.isEmpty &&
            !acid.isEmpty &&
            !deviceId.isEmpty &&
            !status.isEmpty
        }
    }
}

/// Creates a JSON body for an in-app subscription request.
///
/// - Parameter data: The `InAppSubscribeRequestData` containing subscription details.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createInAppSubscribeJSONBody(
    data: RequestModel.InAppSubscribeRequestData
) -> Data? {
    let keys = InAppConstants.JSONKeys.self

    let catsArray: [[String: Any]] = data.cats?.map { cat in
        var dict: [String: Any] = [:]
        if let name = cat.name { dict[keys.catsName] = name }
        if let title = cat.title { dict[keys.catsTitle] = title }
        if let steady = cat.steady { dict[keys.catsSteady] = steady }
        if let active = cat.active { dict[keys.catsActive] = active }
        return dict
    } ?? []

    let subscription: [String: Any] = [
        keys.subscriptionId: data.deviceId,
        keys.status: data.status,
        keys.fields: data.fields ?? NSNull(),
        keys.cats: catsArray
    ]

    let json: [String: Any] = [
        keys.sync: data.sync,
        keys.acid: data.acid,
        keys.profileFields: data.profileFields ?? NSNull(),
        keys.time: data.time,
        keys.subscription: subscription,
        keys.replace: data.replace == true,
        keys.skipTriggers: data.skipTriggers == true
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for an in-app subscription action.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `InAppSubscribeRequestData` containing subscription parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func inAppSubscribeRequest(
    data: RequestModel.InAppSubscribeRequestData
) async -> URLRequest? {
    guard let requestBody = createInAppSubscribeJSONBody(
        data: data
    ) else {
        return nil
    }

    return await CoreRequestBuilder.post(
        path: data.path,
        body: requestBody,
        queryItems: [
            URLQueryItem(
                name: InAppConstants.QueryItem.sync,
                value: toQueryValue(data.sync)
            )
        ],
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
