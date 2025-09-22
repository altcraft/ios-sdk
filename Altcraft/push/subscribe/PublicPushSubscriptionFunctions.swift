//
//  PublicSubscribeFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import Foundation

public class PublicPushSubscriptionFunctions {
    
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

    /// Suspends push notifications for the current profile.
    ///
    /// - Parameters:
    ///   - sync: Whether the call is synchronous (`true`) or asynchronous (`false`). Default is `true`.
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include.
    ///   - cats: Optional category map.
    ///   - replace: Whether to replace an existing subscription.
    ///   - skipTriggers: Whether to skip trigger execution.
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
    
    /// Sends an unSuspend request and wraps the response with the HTTP status code.
    ///
    /// The response is returned inside `ResponseWithHttp`, or `nil` on failure.
    /// This function does not persist or retry the request.
    ///
    /// - Parameter completion: Closure receiving `ResponseWithHttp` or `nil`.
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

    /// Returns the status of the latest subscription in profile.
    /// Equivalent to Kotlin's getStatusOfLatestSubscription().
    ///
    /// - Parameters:
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    public func getStatusOfLatestSubscription(completion: @escaping (ResponseWithHttp?) -> Void) {
        let mode = Constants.StatusMode.latestSubscription

        statusRequest(mode: mode) { request in
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

    /// Returns the status of a subscription matching the current push token and provider.
    /// Equivalent to Kotlin's getStatusForCurrentSubscription().
    ///
    /// - Parameters:
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    public func getStatusForCurrentSubscription(completion: @escaping (ResponseWithHttp?) -> Void) {
        let mode = Constants.StatusMode.matchCurrentContext

        statusRequest(mode: mode) { request in
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

    /// Returns the status of the latest subscription for a push provider.
    /// If `provider` is specified, queries the latest subscription for that provider.
    /// If `nil`, uses the current push provider.
    /// Equivalent to Kotlin's getStatusOfLatestSubscriptionForProvider().
    ///
    /// - Parameters:
    ///   - provider: Optional push provider identifier (`"ios-apns"`  `"ios-firebase"`, `"ios-huawei"`). If `nil`, the current provider is used.
    ///   - completion: Callback invoked with `ResponseWithHttp` (contains HTTP status and parsed `Response`)
    ///                 or `nil` if validation fails or the request could not be created/sent.
    public func getStatusOfLatestSubscriptionForProvider(
        provider: String? = nil,
        completion: @escaping (ResponseWithHttp?) -> Void
    ) {
        if let p = provider, !TokenManager.shared.validProviders.contains(p) {
            errorEvent(#function, error: invalidPushProviders)
            completion(nil)
            return
        }

        let mode = Constants.StatusMode.latestForProvider

        statusRequest(mode: mode, provider: provider) { request in
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
    
    /// Creates an `ActionFieldBuilder` for the specified profile field key.
    ///
    /// - Parameter key: The profile field key..
    /// - Returns: A builder to define action (`set`, `incr`, etc.) for the field.
    public func actionField(key: String) -> ActionFieldBuilder {
        return ActionFieldBuilder(key: key)
    }

    /// Example usage:
    /// You can construct a `profileFields` dictionary with structured updates:
    ///
    ///```swift
    /// AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
    /// profileFields: actionField(key: "_fname").set(value: "Andrey"
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
