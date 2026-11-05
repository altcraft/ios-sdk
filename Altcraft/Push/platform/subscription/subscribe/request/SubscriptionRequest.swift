//
//  SubscriptionRequest.swift
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

    /// Represents the data required to create a push subscription request.
    ///
    /// - Properties:
    ///   - path: Relative API endpoint path.
    ///   - requestId: Unique request ID.
    ///   - time: Request timestamp in epoch milliseconds.
    ///   - provider: Push provider name, for example `"ios-apns"` or `"ios-firebase"`.
    ///   - deviceToken: Current device token.
    ///   - status: Subscription status.
    ///   - sync: Request execution mode:
    ///     - `true` — synchronous mode, the server returns the final result.
    ///     - `false` — asynchronous mode, the server returns acceptance or queue status only.
    ///   - profileFields: Profile fields payload.
    ///   - fields: Extra subscription fields payload.
    ///   - cats: Category list payload.
    ///   - replace: If `true`, replaces an existing subscription.
    ///   - skipTriggers: If `true`, skips trigger execution.
    struct PushSubscribeRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithProfile

        let path: String
        let requestId: String
        let time: Int64
        let provider: String
        let deviceToken: String
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
            provider: String,
            deviceToken: String,
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
            self.provider = provider
            self.deviceToken = deviceToken
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
            case PushConstants.SubStatus.subscribed:
                return PushConstants.RequestName.subscribe
            case PushConstants.SubStatus.suspended:
                return PushConstants.RequestName.suspend
            default:
                return PushConstants.RequestName.unsubscribe
            }
        }

        var successEvent: any SDKEvent {
            switch status {
            case PushConstants.SubStatus.subscribed:
                return PushModuleEvents.pushSubscribeRequestSuccessful
            case PushConstants.SubStatus.suspended:
                return PushModuleEvents.pushSuspendRequestSuccessful
            default:
                return PushModuleEvents.pushUnsubscribeRequestSuccessful
            }
        }

        var failedEvent: any SDKEvent {
            switch status {
            case PushConstants.SubStatus.subscribed:
                return PushModuleEvents.pushSubscribeRequestFailed
            case PushConstants.SubStatus.suspended:
                return PushModuleEvents.pushSuspendRequestFailed
            default:
                return PushModuleEvents.pushUnsubscribeRequestFailed
            }
        }

        var responseType: Response.Type {
            Response.self
        }

        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { PushLog.MODULE_PREFIX }

        var isValid: Bool {
            time > 0 &&
            !requestId.isEmpty &&
            !provider.isEmpty &&
            !deviceToken.isEmpty &&
            !status.isEmpty
        }
    }
}

/// Creates a JSON body for a push subscription request.
///
/// - Parameter data: The `PushSubscribeRequestData` containing subscription details.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createPushSubscribeJSONBody(
    data: RequestModel.PushSubscribeRequestData
) -> Data? {
    let keys = PushConstants.JSONKeys.self

    let catsArray: [[String: Any]] = data.cats?.map { cat in
        var dict: [String: Any] = [:]
        if let name = cat.name { dict[keys.catsName] = name }
        if let title = cat.title { dict[keys.catsTitle] = title }
        if let steady = cat.steady { dict[keys.catsSteady] = steady }
        if let active = cat.active { dict[keys.catsActive] = active }
        return dict
    } ?? []

    let subscription: [String: Any] = [
        keys.subscriptionId: data.deviceToken,
        keys.provider: data.provider,
        keys.status: data.status,
        keys.fields: data.fields ?? NSNull(),
        keys.cats: catsArray
    ]

    let json: [String: Any] = [
        keys.time: data.time,
        keys.subscriptionId: data.deviceToken,
        keys.subscription: subscription,
        keys.profileFields: data.profileFields ?? NSNull(),
        keys.replace: data.replace == true,
        keys.skipTriggers: data.skipTriggers == true
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

/// Creates a complete URL request for a push subscription action.
///
/// The base URL, authorization header, and matching mode are resolved by Core.
///
/// - Parameter data: The `PushSubscribeRequestData` containing subscription parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func pushSubscribeRequest(
    data: RequestModel.PushSubscribeRequestData
) async -> URLRequest? {
    guard let requestBody = createPushSubscribeJSONBody(
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
                name: PushConstants.QueryItem.sync,
                value: toQueryValue(data.sync)
            )
        ],
        requestId: data.requestId,
        includeMatchingMode: true
    )
}
