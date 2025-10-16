//
//  PublicTokenFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

/// Public interface for setting push token providers (FCM, HMS, APNs)
/// and working with tokens from Swift/Objective-C.
@objcMembers
public class PublicPushTokenFunctions: NSObject {

    public static let shared = PublicPushTokenFunctions()
    private let tokenManager = TokenManager.shared


    /// Sets the Firebase Cloud Messaging (FCM) token provider.
    ///
    /// - Parameter provider: The `FCMInterface` implementation to be used, or `nil` to unset it.
    public func setFCMTokenProvider(_ provider: FCMInterface?) {
        tokenManager.fcmProvider = provider
    }

    /// Sets the Huawei Mobile Services (HMS) token provider.
    ///
    /// - Parameter provider: The `HMSInterface` implementation to be used, or `nil` to unset it.
    public func setHMSTokenProvider(_ provider: HMSInterface?) {
        tokenManager.hmsProvider = provider
    }

    /// Sets the Apple Push Notification Service (APNs) token provider.
    ///
    /// - Parameter provider: The `APNSInterface` implementation to be used, or `nil` to unset it.
    public func setAPNSTokenProvider(_ provider: APNSInterface?) {
        tokenManager.apnsProvider = provider
    }

    /// Asynchronously retrieves the current push token (Swift).
    ///
    /// - Parameter completion: Called with `TokenData?` (nil if unavailable).
    public func getPushToken(completion: ((TokenData?) -> Void)? = nil) {
        tokenManager.getCurrentToken { tokenData in
            completion?(tokenData)
        }
    }

    /// ObjC-only: Asynchronously retrieves the current push token as `TokenDataObjC`.
    ///
    /// Selector (ObjC): `getPushToken:`
    /// Hidden from Swift to avoid duplicate selectors and keep
    /// the same method name with separate visibility.
    @available(swift, obsoleted: 1)
    @objc(getPushToken:)
    public func getPushTokenObjC(_ completion: ((TokenDataObjC?) -> Void)? = nil) {
        tokenManager.getCurrentToken { tokenData in
            let bridged = TokenDataObjC.from(tokenData)
            completion?(bridged)
        }
    }

    /// Updates the device token for Firebase, Huawei or APNs in UserDefaults.
    ///
    /// - Parameters:
    ///   - provider: One of: `"firebase"`, `"huawei"`, `"apns"`.
    ///   - pushToken: `String` (FCM/HMS) or `Data` (APNs). Pass `nil` to clear.
    public func setPushToken(provider: String, pushToken: Any?) {
        guard tokenManager.validProviders.contains(provider) else {
            errorEvent(
                #function,
                error: invalidPushProviders,
                value: [Constants.MapKeys.provider: provider]
            )
            return
        }

        let token: String? = (pushToken as? String) ?? (pushToken as? Data).map {
            $0.map { String(format: "%02x", $0) }.joined()
        }

        StoredVariablesManager.shared.setPushToken(provider: provider, token: token)
    }

    /// Updates the provider priority list in the local configuration and triggers token update.
    ///
    /// - Parameter list: Array of provider identifiers (e.g. `["apns","firebase","huawei"]`).
    public func changePushProviderPriorityList(_ list: [String]) {
        guard tokenManager.allProvidersValid(list) else {
            errorEvent(#function, error: invalidPushProviders)
            return
        }

        updateProviderPriorityList(newList: list) { result in
            switch result {
            case .success():
                TokenUpdate.shared.tokenUpdate()
            case .failure(let error):
                errorEvent(#function, error: error)
            }
        }
    }

    /// Deletes the device token for a specified provider.
    ///
    /// - Parameters:
    ///   - provider: `"firebase"`, `"huawei"`, or `"apns"`.
    ///   - completion: Invoked after deletion finishes.
    public func deleteDeviceToken(provider: String, completion: @escaping () -> Void) {
        switch provider {
        case Constants.ProviderName.firebase:
            tokenManager.deleteFCMToken { _ in completion() }
        case Constants.ProviderName.huawei:
            tokenManager.deleteHMSToken { _ in completion() }
        case Constants.ProviderName.apns:
            errorEvent(#function, error: apnsIsNotUpdated)
            completion()
        default:
            errorEvent(#function, error: invalidPushProviders)
            completion()
        }
    }

    /// Forces a token refresh by deleting the current token and starting the update flow.
    ///
    /// - Parameter completion: Called when the flow finishes (optional).
    public func forcedTokenUpdate(completion: (() -> Void)? = nil) {
        tokenManager.getCurrentToken { tokenData in
            guard let tokenData = tokenData else {
                errorEvent(#function, error: currentTokenIsNil)
                completion?()
                return
            }

            let provider = tokenData.provider

            if provider == Constants.ProviderName.apns {
                errorEvent(#function, error: apnsIsNotUpdated)
                completion?()
                return
            }

            self.deleteDeviceToken(provider: provider) {
                getContext { _ in
                    TokenUpdate.shared.tokenUpdate() {
                        completion?()
                    }
                }
            }
        }
    }
}
