//
//  SubscribeAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public facade for In-App subscription and status operations.
///
/// Exposes native Swift methods and Objective-C wrappers that accept Foundation
/// collections and return Objective-C-friendly DTOs where needed.
@objcMembers
@available(iOSApplicationExtension, unavailable)
public final class SubscribeAPI: NSObject, @unchecked Sendable {

    /// Shared In-App subscribe API instance.
    public static let shared: SubscribeAPI = {
        InApp.ensureRegistered()
        return SubscribeAPI()
    }()

    /// Sends an In-App subscription request with the specified status.
    ///
    /// Validates that `customFields` contains only primitive values, encodes
    /// parameters, and submits the request on the entity queue.
    ///
    /// - Parameters:
    ///   - status: Subscription status to send.
    ///   - sync: Whether the request is synchronous on the server.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields. Must contain only primitive values.
    ///   - cats: Optional category list.
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    func inAppSubscription(
        status: String,
        sync: Bool,
        profileFields: [String: Any?]?,
        customFields: [String: Any?]?,
        cats: [CategoryData]?,
        replace: Bool?,
        skipTriggers: Bool?
    ) {
        if (customFields ?? [:]).containsNonPrimitiveValues() {
            InAppLog.error(#function, error: CoreEvents.fieldsIsObjects)
            return
        }

        let encodedCats = encodeCats(cats)
        let encodedProfileFields = encodeAnyMap(profileFields)
        let encodedCustomFields = encodeAnyMap(customFields)

        InAppSubscribeQueues.entityQueue.submit {
            await InAppSubscriptionProcess.shared.inAppSubscribe(
                status: status,
                sync: sync,
                profileFields: encodedProfileFields,
                customFields: encodedCustomFields,
                cats: encodedCats,
                replace: replace,
                skipTriggers: skipTriggers
            )
        }
    }

    /// Performs an In-App subscription request.
    ///
    /// - Parameters:
    ///   - sync: Whether the request is synchronous on the server.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields. Must contain only primitive values.
    ///   - cats: Optional category list.
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func subscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        inAppSubscription(
            status: InAppConstants.SubStatus.subscribed,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper for In-App subscription.
    @available(swift, obsoleted: 1)
    @objc(inAppSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
    public func subscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        subscribe(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Performs an In-App unsubscription request.
    ///
    /// - Parameters:
    ///   - sync: Whether the request is synchronous on the server.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields. Must contain only primitive values.
    ///   - cats: Optional category list.
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func unsubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        inAppSubscription(
            status: InAppConstants.SubStatus.unsubscribed,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper for In-App unsubscription.
    @available(swift, obsoleted: 1)
    @objc(inAppUnsubscribe:profileFields:customFields:cats:replace:skipTriggers:)
    public func unsubscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        unsubscribe(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    // MARK: - In-App Subscription PushStatusProcess

    /// Returns the current In-App subscription status.
    ///
    /// - Parameter completion: Callback invoked with response and HTTP code, or `nil`.
    @nonobjc
    public func getSubscriptionStatus(
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        Task {
            guard let data = await getInAppStatusRequestData() else {
                InAppLog.error(
                    #function,
                    error: InAppModuleEvents.inAppStatusRequestDataIsNil
                )
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            guard let urlRequest = await inAppStatusRequest(data: data) else {
                InAppLog.error(
                    #function,
                    error: CoreEvents.failedCreateRequest
                )
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            let result = await RequestManager.shared.sendRequest(
                request: urlRequest,
                requestData: data
            )

            let response = ResponseModel.ResponseWithHttpCode(
                httpCode: result.httpCode,
                response: result.response
            )

            await MainActor.run {
                completion(response)
            }
        }
    }

    /// ObjC wrapper for current In-App subscription status.
    ///
    /// - Parameter completion: Callback invoked with Objective-C-friendly response and HTTP code, or `nil`.
    @available(swift, obsoleted: 1)
    @objc(getInAppSubscriptionStatusWithCompletion:)
    public func getSubscriptionStatus(
        _ completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        getSubscriptionStatus { response in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }
}

/// Builds `InAppStatusRequestData` used for in-app subscription status
/// requests.
///
/// - Returns: Valid in-app status request data, or `nil` on failure.
func getInAppStatusRequestData() async -> RequestModel.InAppStatusRequestData? {
    let env = InAppEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let internalAuth = try await env.internalAuth()

        return RequestModel.InAppStatusRequestData(
            path: InAppConstants.UrlPath.status,
            requestId: UUID().uuidString,
            deviceId: internalAuth.deviceId
        )
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}
