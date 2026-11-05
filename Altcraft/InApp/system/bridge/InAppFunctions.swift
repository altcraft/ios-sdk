//
//  InAppFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Objective-C bridge for the in-app module API.
///
/// Exposes the `InApp` facade to Objective-C callers. All methods delegate to
/// ``InApp``.
@objcMembers
@objc(PublicInAppFunctions)
@available(iOSApplicationExtension, unavailable)
final class InAppFunctions: NSObject, @unchecked Sendable {

    /// Shared in-app functions instance.
    static let shared = InAppFunctions()

    private override init() {}

    /// Registers SDK lifecycle observers used by in-app flows.
    func registerLifecycleTracking() {
        InApp.shared.registerLifecycleTracking()
    }

    /// Sets the current screen used for In-App placement matching.
    func setScreen(screen: String) {
        InApp.shared.setScreen(screen: screen)
    }

    /// Requests available in-app placements from the backend.
    func getInAppPlacements() {
        InApp.shared.getPlacements()
    }

    /// Triggers processing of In-App campaigns associated with the given trigger.
    func inAppTrigger(name: String) {
        InApp.shared.trigger(name: name)
    }

    /// Sets animation hook for the in-app view.
    func setAnimation(
        _ block: @escaping @MainActor (InAppAnimator) -> Void
    ) {
        InApp.shared.animation(block)
    }

    /// Performs an In-App subscription request.
    @nonobjc
    func inAppSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        InApp.shared.subscription.subscribe(
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
    func inAppSubscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        inAppSubscribe(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Performs an In-App unsubscription request.
    @nonobjc
    func inAppUnSubscribe(
        sync: Bool = true,
        profileFields: [String: Any?]? = nil,
        customFields: [String: Any?]? = nil,
        cats: [CategoryData]? = nil,
        replace: Bool? = nil,
        skipTriggers: Bool? = nil
    ) {
        InApp.shared.subscription.unsubscribe(
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
    @objc(inAppUnSubscribe:profileFields:customFields:cats:replace:skipTriggers:)
    func inAppUnSubscribe(
        _ sync: Bool,
        profileFields: NSDictionary? = nil,
        customFields: NSDictionary? = nil,
        cats: [CategoryDataObjC]? = nil,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) {
        inAppUnSubscribe(
            sync: sync,
            profileFields: profileFields as? [String: Any?],
            customFields: customFields as? [String: Any?],
            cats: CategoryDataObjC.toSwiftArray(cats),
            replace: replace,
            skipTriggers: skipTriggers
        )
    }

    /// Returns the current In-App subscription status.
    @nonobjc
    func getInAppSubscriptionStatus(
        completion: @escaping @Sendable (
            ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?
        ) -> Void
    ) {
        InApp.shared.subscription.getSubscriptionStatus(completion: completion)
    }

    /// ObjC wrapper for current In-App subscription status.
    ///
    /// - Parameter completion: Callback invoked with Objective-C-friendly response and HTTP code, or `nil`.
    @available(swift, obsoleted: 1)
    @objc(getInAppSubscriptionStatusWithCompletion:)
    func getInAppSubscriptionStatus(
        _ completion: @escaping (ResponseWithHttpCodeObjC?) -> Void
    ) {
        let completionBox = CallbackBox<ResponseWithHttpCodeObjC?>(completion)

        InApp.shared.subscription.getSubscriptionStatus { (response: ResponseModel.ResponseWithHttpCode<ResponseModel.ResponseWithProfile>?) in
            completionBox.call(ResponseWithHttpCodeObjC.from(response))
        }
    }
}
