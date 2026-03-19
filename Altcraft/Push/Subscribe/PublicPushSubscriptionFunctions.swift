//
//  PublicPushSubscriptionFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

/// Public facade for push subscription operations.
///
/// Exposes native Swift methods (your existing API) **and** Objective-C wrappers
/// that accept Foundation collections (`NSDictionary`, `NSArray`) and return
/// Objective-C-friendly DTOs where needed.
@objcMembers
@available(iOSApplicationExtension, unavailable)
public class PublicPushSubscriptionFunctions: NSObject, @unchecked Sendable {
    
    public static let shared = PublicPushSubscriptionFunctions()
    
    /// Performs a push **push subscription** request.
    ///
    /// - Parameters:
    ///   - sync: Whether the call should be treated as synchronous (`true`)
    ///    or asynchronous (`false`) on the server (default `true`).
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include. Must contain only primitive values.
    ///   - cats: Optional list of categories (`[CategoryData]`).
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func pushSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        let encodedCats = encodeCats(cats)
        let encodedProfileFields = encodeAnyMap(profileFields)
        let encodedCustomFields = encodeAnyMap(customFields)
        
        if (customFields ?? [:]).containsNonPrimitiveValues() {
            errorEvent(#function, error: fieldsIsObjects)
            return
        }
        
        SubscribeQueues.entityQueue.submit {
            await PushSubscribe.shared.pushSubscribe(
                status: Constants.SubStatus.subscribed,
                sync: sync ? 1 : 0,
                profileFields: encodedProfileFields,
                customFields: encodedCustomFields,
                cats: encodedCats,
                replace: replace,
                skipTriggers: skipTriggers
            )
        }
    }
    
    /// ObjC wrapper: subscribe (bridges Foundation types and `CategoryDataObjC`).
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
    
    /// Performs a push **push unsubscription** request.
    ///
    /// - Parameters:
    ///   - sync: Whether the call should be treated as synchronous (`true`)
    ///   or asynchronous (`false`) on the server (default `true`).
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include. Must contain only primitive values.
    ///   - cats: Optional list of categories (`[CategoryData]`).
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func pushUnSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        let encodedCats = encodeCats(cats)
        let encodedProfileFields = encodeAnyMap(profileFields)
        let encodedCustomFields = encodeAnyMap(customFields)
        
        if (customFields ?? [:]).containsNonPrimitiveValues() {
            errorEvent(#function, error: fieldsIsObjects)
            return
        }
        
        SubscribeQueues.entityQueue.submit {
            await PushSubscribe.shared.pushSubscribe(
                status: Constants.SubStatus.unsubscribed,
                sync: sync ? 1 : 0,
                profileFields: encodedProfileFields,
                customFields: encodedCustomFields,
                cats: encodedCats,
                replace: replace,
                skipTriggers: skipTriggers
            )
        }
    }
    
    /// ObjC wrapper: unsubscribe (bridges Foundation types and `CategoryDataObjC`).
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
    ///   - sync: Whether the call should be treated as synchronous (`true`)
    ///   or asynchronous (`false`) on the server (default `true`).
    ///   - profileFields: Optional profile fields to include.
    ///   - customFields: Optional custom fields to include. Must contain only primitive values.
    ///   - cats: Optional list of categories (`[CategoryData]`).
    ///   - replace: Whether to replace existing subscription data.
    ///   - skipTriggers: Whether to skip automation triggers.
    @nonobjc
    public func pushSuspend(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        let encodedCats = encodeCats(cats)
        let encodedProfileFields = encodeAnyMap(profileFields)
        let encodedCustomFields = encodeAnyMap(customFields)
        
        if (customFields ?? [:]).containsNonPrimitiveValues() {
            errorEvent(#function, error: fieldsIsObjects)
            return
        }
        
        SubscribeQueues.entityQueue.submit {
            await PushSubscribe.shared.pushSubscribe(
                status: Constants.SubStatus.suspended,
                sync: sync ? 1 : 0,
                profileFields: encodedProfileFields,
                customFields: encodedCustomFields,
                cats: encodedCats,
                replace: replace,
                skipTriggers: skipTriggers
            )
        }
    }
    
    /// ObjC wrapper: suspend (bridges Foundation types and `CategoryDataObjC`).
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
    public func unSuspendPushSubscription(
        completion: @escaping @Sendable (ResponseWithHttp?) -> Void
    ) {
        Task {
            guard let data = await getUnSuspendRequestData() else {
                errorEvent(#function, error: unSuspendRequestDataIsNil)
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            guard let request = unSuspendRequest(data: data) else {
                errorEvent(#function, error: failedCreateRequest)
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            let result = await RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.unsuspend
            )
            
            let response = result.value?[
                Constants.MapKeys.responseWithHttp
            ] as? ResponseWithHttp
            
            await MainActor.run {
                completion(response)
            }
        }
    }
    
    /// ObjC wrapper: unsuspend (bridges to `ResponseWithHttpObjC`).
    @available(swift, obsoleted: 1)
    @objc(unSuspendPushSubscriptionWithCompletion:)
    public func unSuspendPushSubscription(
        _ completion: @escaping (ResponseWithHttpObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpObjC?>(completion)
        
        self.unSuspendPushSubscription { response in
            let objcResponse = ResponseWithHttpObjC.from(response)
            completionBox.call(objcResponse)
        }
    }
    
    /// Returns the status of the latest subscription in profile.
    ///
    /// - Parameter completion: Callback invoked with `ResponseWithHttp` or `nil`.
    @nonobjc
    public func getStatusOfLatestSubscription(
        completion: @escaping @Sendable (ResponseWithHttp?) -> Void
    ) {
        Task {
            guard let request = await statusRequest(
                mode: Constants.StatusMode.latestSubscription
            ) else {
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            let result = await RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            )
            
            let response = result.value?[
                Constants.MapKeys.responseWithHttp
            ] as? ResponseWithHttp
            
            await MainActor.run {
                completion(response)
            }
        }
    }
    
    /// ObjC wrapper: latest status.
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionWithCompletion:)
    public func getStatusOfLatestSubscription(
        _ completion: @escaping (ResponseWithHttpObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpObjC?>(completion)
        
        self.getStatusOfLatestSubscription { response in
            let objcResponse = ResponseWithHttpObjC.from(response)
            completionBox.call(objcResponse)
        }
    }
    
    /// Returns the status of a subscription matching the current push token and provider.
    ///
    /// - Parameter completion: Callback invoked with `ResponseWithHttp` or `nil`.
    @nonobjc
    public func getStatusForCurrentSubscription(
        completion: @escaping @Sendable (ResponseWithHttp?) -> Void
    ) {
        Task {
            guard let request = await statusRequest(
                mode: Constants.StatusMode.matchCurrentContext
            ) else {
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            let result = await RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            )
            
            let response = result.value?[
                Constants.MapKeys.responseWithHttp
            ] as? ResponseWithHttp
            
            await MainActor.run {
                completion(response)
            }
        }
    }
    
    /// ObjC wrapper: current status.
    @available(swift, obsoleted: 1)
    @objc(getStatusForCurrentSubscriptionWithCompletion:)
    public func getStatusForCurrentSubscription(
        _ completion: @escaping (ResponseWithHttpObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpObjC?>(completion)
        
        self.getStatusForCurrentSubscription { response in
            let objcResponse = ResponseWithHttpObjC.from(response)
            completionBox.call(objcResponse)
        }
    }
    
    /// Returns the status of the latest subscription for a push provider.
    ///
    /// - Parameters:
    ///   - provider: Optional push provider identifier.
    ///   - completion: Callback invoked with `ResponseWithHttp` or `nil`.
    @nonobjc
    public func getStatusOfLatestSubscriptionForProvider(
        provider: String? = nil,
        completion: @escaping @Sendable (ResponseWithHttp?) -> Void
    ) {
        Task {
            if let p = provider, !TokenManager.shared.validProviders.contains(p) {
                errorEvent(#function, error: invalidPushProviders)
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            guard let request = await statusRequest(
                mode: Constants.StatusMode.latestForProvider,
                provider: provider
            ) else {
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            let result = await RequestManager.shared.sendRequest(
                request: request,
                requestName: Constants.RequestName.status
            )
            
            let response = result.value?[
                Constants.MapKeys.responseWithHttp
            ] as? ResponseWithHttp
            
            await MainActor.run {
                completion(response)
            }
        }
    }
    
    /// ObjC wrapper: latest status for provider.
    @available(swift, obsoleted: 1)
    @objc(getStatusOfLatestSubscriptionForProvider:completion:)
    public func getStatusOfLatestSubscriptionForProvider(
        _ provider: String?,
        completion: @escaping (ResponseWithHttpObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpObjC?>(completion)
        
        self.getStatusOfLatestSubscriptionForProvider(provider: provider) { response in
            let objcResponse = ResponseWithHttpObjC.from(response)
            completionBox.call(objcResponse)
        }
    }
    
    /// Creates an `ActionFieldBuilder` for the specified profile field key.
    ///
    /// - Parameter key: The profile field key.
    /// - Returns: A builder to define action (`set`, `incr`, etc.) for the field.
    public func actionField(key: String) -> ActionFieldBuilder {
        return ActionFieldBuilder(key: key)
    }
}
