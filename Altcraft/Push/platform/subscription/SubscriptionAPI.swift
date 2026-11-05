//
//  SubscriptionAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public facade for push subscription operations.
///
/// Exposes native Swift methods and Objective-C wrappers that accept Foundation
/// collections and return Objective-C-friendly DTOs where needed.
@objcMembers
@objc(PublicPushSubscriptionFunctions)
@available(iOSApplicationExtension, unavailable)
public class SubscriptionAPI: NSObject, @unchecked Sendable {

    /// Shared public push subscription functions instance.
    public static let shared: SubscriptionAPI = {
        Push.ensureRegistered()
        return SubscriptionAPI()
    }()

    /// Sends a push subscription request with the specified status.
    ///
    /// - Parameters:
    ///   - status: Subscription status to send.
    ///   - sync: Whether the request is synchronous on the server.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields. Must contain only primitive values.
    ///   - cats: Optional category list.
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    private func pushSubscription(
        status: String,
        sync: Bool,
        profileFields: [String: Any?]?,
        customFields: [String: Any?]?,
        cats: [CategoryData]?,
        replace: Bool?,
        skipTriggers: Bool?
    ) {
        if (customFields ?? [:]).containsNonPrimitiveValues() {
            PushLog.error(#function, error: CoreEvents.fieldsIsObjects)
            return
        }

        let encodedCats = encodeCats(cats)
        let encodedProfileFields = encodeAnyMap(profileFields)
        let encodedCustomFields = encodeAnyMap(customFields)

        PushSubscribeQueues.entityQueue.submit {
            await PushSubscriptionProcess.shared.pushSubscribe(
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

    /// Performs a push subscription request.
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
        pushSubscription(
            status: PushConstants.SubStatus.subscribed,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper for push subscription.
    @available(swift, obsoleted: 1)
    @objc(pushSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
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

    /// Performs a push unsubscription request.
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
        pushSubscription(
            status: PushConstants.SubStatus.unsubscribed,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper for push unsubscription.
    @available(swift, obsoleted: 1)
    @objc(pushUnSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
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

    /// Suspends push notifications for the current profile.
    ///
    /// - Parameters:
    ///   - sync: Whether the request is synchronous on the server.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields. Must contain only primitive values.
    ///   - cats: Optional category list.
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func suspend(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        pushSubscription(
            status: PushConstants.SubStatus.suspended,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper for push suspension.
    @available(swift, obsoleted: 1)
    @objc(pushSuspend:profileFields:customFields:cats:replace:skipTriggers:)
    public func suspend(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        suspend(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Sends an unsuspend request and returns response with HTTP status code.
    ///
    /// - Parameter completion: Callback invoked with response and HTTP code, or `nil`.
    @nonobjc
    public func unSuspend(
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        Task {
            guard let data = await getUnSuspendRequestData() else {
                PushLog.error(#function, error: PushModuleEvents.unsuspendRequestDataIsNil)
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            guard let request = await unSuspendRequest(data: data) else {
                PushLog.error(#function, error: CoreEvents.failedCreateRequest)
                await MainActor.run {
                    completion(nil)
                }
                return
            }

            let result = await RequestManager.shared.sendRequest(
                request: request,
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

    /// ObjC wrapper for unsuspend request.
    @available(swift, obsoleted: 1)
    @objc(unSuspendPushSubscriptionWithCompletion:)
    public func unSuspend(
        _ completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        unSuspend { response in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }

    /// Creates an `ActionFieldBuilder` for the specified profile field key.
    ///
    /// - Parameter key: Profile field key.
    /// - Returns: Builder for field action configuration.
    public func actionField(key: String) -> ActionFieldBuilder {
        ActionFieldBuilder(key: key)
    }

    // MARK: - Push Subscription PushStatusProcess

    /// Returns the status of the latest subscription in profile.
    ///
    /// - Parameter completion: Callback invoked with response and HTTP code, or `nil`.
    @nonobjc
    public func latest(
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        Task {
            let response = await PushStatusWorker.shared.getStatusOfLatestSubscription()

            await MainActor.run {
                completion(response)
            }
        }
    }

    /// ObjC wrapper for latest subscription status.
    ///
    /// - Parameter completion: Callback invoked with Objective-C-friendly response and HTTP code, or `nil`.
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionWithCompletion:)
    public func latest(
        _ completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        latest { response in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }

    /// Returns the status of a subscription matching the current token and provider.
    ///
    /// - Parameter completion: Callback invoked with response and HTTP code, or `nil`.
    @nonobjc
    public func current(
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        Task {
            let response = await PushStatusWorker.shared.getStatusForCurrentSubscription()

            await MainActor.run {
                completion(response)
            }
        }
    }

    /// ObjC wrapper for current subscription status.
    ///
    /// - Parameter completion: Callback invoked with Objective-C-friendly response and HTTP code, or `nil`.
    @available(swift, obsoleted: 1)
    @objc(getStatusForCurrentSubscriptionWithCompletion:)
    public func current(
        _ completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        current { response in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }

    /// Returns the status of the latest subscription for a push provider.
    ///
    /// - Parameters:
    ///   - provider: Optional push provider identifier.
    ///   - completion: Callback invoked with response and HTTP code, or `nil`.
    @nonobjc
    public func latestForProvider(
        provider: String? = nil,
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        Task {
            let response = await PushStatusWorker.shared.getStatusOfLatestSubscriptionForProvider(
                provider: provider
            )

            await MainActor.run {
                completion(response)
            }
        }
    }

    /// ObjC wrapper for latest subscription status by provider.
    ///
    /// - Parameters:
    ///   - provider: Optional push provider identifier.
    ///   - completion: Callback invoked with Objective-C-friendly response and HTTP code, or `nil`.
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionForProvider:completion:)
    public func latestForProvider(
        _ provider: String?,
        completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        latestForProvider(provider: provider) { response in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }
}

/// Builds `UnSuspendRequestData` required for the unsuspend API call.
///
/// - Returns: Valid unsuspend request data, or `nil` on failure.
func getUnSuspendRequestData() async -> RequestModel.UnSuspendRequestData? {
    let env = PushEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let token = try await env.currentToken()

        return RequestModel.UnSuspendRequestData(
            path: PushConstants.UrlPath.unsuspend,
            requestId: UUID().uuidString,
            provider: token.provider,
            token: token.token
        )
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}
