//
//  PublicSubscribeFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Public facade for push subscription operations.
///
/// Exposes native Swift methods (your existing API) **and** Objective-C wrappers
/// that accept Foundation collections (`NSDictionary`, `NSArray`) and return
/// Objective-C friendly DTOs where needed.
@objcMembers
public class PublicPushSubscriptionFunctions: NSObject {

    public static let shared = PublicPushSubscriptionFunctions()

    //// Performs a push **subscription** request.
    /// This call blocks until a response is received from the server.
    ///
    /// - Parameters:
    ///   - sync: Whether the call is synchronous (`true`) or asynchronous (`false`). Default is `true`.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include.
    ///   - cats: Optional category map.
    ///   - replace: Whether to replace an existing subscription.
    ///   - skipTriggers: Whether to skip trigger execution.
    @nonobjc
    public func pushSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        PushSubscribe.shared.pushSubscribe(
            status: Constants.Status.subscribe.rawValue,
            sync: sync ? 1 : 0,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper: subscribe (BOOL sync; Foundation/ObjC types)
    @available(swift, obsoleted: 1)
    @objc(pushSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
    public func pushSubscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        self.pushSubscribe(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Performs a push **unsubscription** request.
    /// This call blocks until a response is received from the server.
    ///
    /// - Parameters:
    ///   - sync: Whether the call is synchronous (`true`) or asynchronous (`false`). Default is `true`.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include.
    ///   - cats: Optional category map.
    ///   - replace: Whether to replace an existing subscription.
    ///   - skipTriggers: Whether to skip trigger execution.
    @nonobjc
    public func pushUnSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        PushSubscribe.shared.pushSubscribe(
            status: Constants.Status.unsubscribe.rawValue,
            sync: sync ? 1 : 0,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper: unsubscribe
    @available(swift, obsoleted: 1)
    @objc(pushUnSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
    public func pushUnSubscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        self.pushUnSubscribe(
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
    ///   - sync: Whether the call is synchronous (`true`) or asynchronous (`false`). Default is `true`.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include.
    ///   - cats: Optional category map.
    ///   - replace: Whether to replace an existing subscription.
    ///   - skipTriggers: Whether to skip trigger execution.
    @nonobjc
    public func pushSuspend(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        PushSubscribe.shared.pushSubscribe(
            status: Constants.Status.suspend.rawValue,
            sync: sync ? 1 : 0,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// ObjC wrapper: suspend
    @available(swift, obsoleted: 1)
    @objc(pushSuspend:profileFields:customFields:cats:replace:skipTriggers:)
    public func pushSuspend(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        self.pushSuspend(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Sends an unSuspend request and wraps the response with the HTTP status code.
    ///
    /// The response is returned inside `ResponseWithHttp`, or `nil` on failure.
    /// This function does not persist or retry the request.
    ///
    /// - Parameter completion: Closure receiving `ResponseWithHttp` or `nil`.
    @nonobjc
    public func unSuspendPushSubscription(completion: @escaping (ResponseWithHttp?) -> Void) {
        getUnSuspendRequestData { data in
            guard let data = data else {
                errorEvent(#function, error: unSuspendRequestDataIsNil)
                completion(nil)
                return
            }

            guard let request = unSuspendRequest(data: data) else {
                errorEvent(#function, error: failedCreateRequest)
                completion(nil)
                return
            }

            RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.unsuspend
            ) { result in
                completion(result.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
            }
        }
    }

    // ObjC wrapper: unsuspend (ResponseWithHttpObjC)
    @available(swift, obsoleted: 1)
    @objc(unSuspendPushSubscriptionWithCompletion:)
    public func unSuspendPushSubscription(_ completion: @escaping (ResponseWithHttpObjC?) -> Void) {
        self.unSuspendPushSubscription { swiftResult in
            completion(ResponseWithHttpObjC.from(swiftResult))
        }
    }

    /// Returns the status of the latest subscription in profile.
    /// Equivalent to Kotlin's getStatusOfLatestSubscription().
    ///
    /// - Parameters:
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    @nonobjc
    public func getStatusOfLatestSubscription(completion: @escaping (ResponseWithHttp?) -> Void) {
        statusRequest(mode: Constants.StatusMode.latestSubscription) { request in
            guard let request = request else {
                completion(nil)
                return
            }
            RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            ) { result in
                completion(result.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
            }
        }
    }

    // ObjC wrapper: latest status
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionWithCompletion:)
    public func getStatusOfLatestSubscription(_ completion: @escaping (ResponseWithHttpObjC?) -> Void) {
        self.getStatusOfLatestSubscription { swiftResult in
            completion(ResponseWithHttpObjC.from(swiftResult))
        }
    }

    /// Returns the status of a subscription matching the current push token and provider.
    /// Equivalent to Kotlin's getStatusForCurrentSubscription().
    ///
    /// - Parameters:
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    @nonobjc
    public func getStatusForCurrentSubscription(completion: @escaping (ResponseWithHttp?) -> Void) {
        statusRequest(mode: Constants.StatusMode.matchCurrentContext) { request in
            guard let request = request else {
                completion(nil)
                return
            }

            RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            ) { result in
                completion(result.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
            }
        }
    }

    // ObjC wrapper: current status
    @available(swift, obsoleted: 1)
    @objc(getStatusForCurrentSubscriptionWithCompletion:)
    public func getStatusForCurrentSubscription(_ completion: @escaping (ResponseWithHttpObjC?) -> Void) {
        self.getStatusForCurrentSubscription { swiftResult in
            completion(ResponseWithHttpObjC.from(swiftResult))
        }
    }

    /// Returns the status of the latest subscription for a push provider.
    /// If `provider` is specified, queries the latest subscription for that provider.
    /// If `nil`, uses the current push provider.
    /// Equivalent to Kotlin's getStatusOfLatestSubscriptionForProvider().
    ///
    /// - Parameters:
    ///   - provider: Optional push provider identifier (`"ios-apns"`, `"ios-firebase"`, `"ios-huawei"`). If `nil`, the current provider is used.
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    @nonobjc
    public func getStatusOfLatestSubscriptionForProvider(
        provider: String? = nil,
        completion: @escaping (ResponseWithHttp?) -> Void
    ) {
        if let p = provider, !TokenManager.shared.validProviders.contains(p) {
            errorEvent(#function, error: invalidPushProviders)
            completion(nil)
            return
        }

        statusRequest(mode: Constants.StatusMode.latestForProvider, provider: provider) { request in
            guard let request = request else {
                completion(nil)
                return
            }

            RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            ) { result in
                completion(result.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
            }
        }
    }

    // ObjC wrapper: latest status for provider
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionForProvider:completion:)
    public func getStatusOfLatestSubscriptionForProvider(
        _ provider: String?,
        completion: @escaping (ResponseWithHttpObjC?) -> Void
    ) {
        self.getStatusOfLatestSubscriptionForProvider(provider: provider) { swiftResult in
            completion(ResponseWithHttpObjC.from(swiftResult))
        }
    }

    
    /// Creates an `ActionFieldBuilder` for the specified profile field key.
    ///
    /// - Parameter key: The profile field key.
    /// - Returns: A builder to define action (`set`, `incr`, etc.) for the field.
    public func actionField(key: String) -> ActionFieldBuilder {
        return ActionFieldBuilder(key: key)
    }

    /// Example usage (Swift):
    /// You can construct a `profileFields` dictionary with structured updates:
    ///
    /// ```swift
    /// AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
    ///     profileFields: actionField(key: "_fname").set(value: "Andrey")
    /// )
    /// ```
    ///
    /// ```swift
    /// AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
    ///     profileFields: mergeFields(
    ///         actionField(key: "_fname").set(value: "Andrey"),
    ///         ["simple_field": "value"]
    ///     )
    /// )
    /// ```
    ///
    /// Supported update actions:
    /// - `set(value:)`
    /// - `unset(value:)`
    /// - `incr(value:)`
    /// - `add(value:)`
    /// - `delete(value:)`
    /// - `upsert(value:)`
}
