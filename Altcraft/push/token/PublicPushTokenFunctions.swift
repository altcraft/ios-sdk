//
//  PublicTokenFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Public interface for setting push token providers (FCM, HMS, APNs).
/// Acts as a facade for internal token management configuration.
public class PublicPushTokenFunctions {

    public static let shared = PublicPushTokenFunctions()
    private let tokenManager = TokenManager.shared

    /// Sets the Firebase Cloud Messaging (FCM) token provider.
    ///
    /// - Parameter provider: The `FCMInterface` implementation to be used,
    /// or `nil` to unset it.
    public func setFCMTokenProvider(_ provider: FCMInterface?) {
        tokenManager.fcmProvider = provider
    }

    /// Sets the Huawei Mobile Services (HMS) token provider.
    ///
    /// - Parameter provider: The `HMSInterface` implementation to be used,
    /// or `nil` to unset it.
    public func setHMSTokenProvider(_ provider: HMSInterface?) {
        tokenManager.hmsProvider = provider
    }

    /// Sets the Apple Push Notification Service (APNs) token provider.
    ///
    /// - Parameter provider: The `APNSInterface` implementation to be used,
    /// or `nil` to unset it.
    public func setAPNSTokenProvider(_ provider: APNSInterface?) {
        tokenManager.apnsProvider = provider
    }
    
    /// Public function to asynchronously retrieve the push token.
    /// The token is returned via the completion handler.
    ///
    /// - Parameter completion: Optional closure that receives the current push token as a `String?`.
    ///   If no token is available, the value will be `nil`. Defaults to `nil`.
    public func getPushToken(completion: ((TokenData?) -> Void)? = nil) {
        tokenManager.getCurrentToken { tokenData in
            completion?(tokenData)
        }
    }
    
    ///Updates the device token for Firebase, Huawei or APNs in UserDefaults.
    ///
    ///- Parameter deviceToken: The device token, either as a `String` for Firebase and Huawey or as `Data` for APNs.
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
    /// Validates the provided list of push providers. If valid, updates the stored configuration
    /// and starts the device token update sequence. If invalid, logs an error and aborts the operation.
    ///
    /// - Parameter list: An array of push provider identifiers .
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
    /// - Parameters:
    ///   - provider: One of the constants: "firebase", "huawei", "apns".
    ///   - completion: Callback invoked after deletion.
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
                getContext { context in
                    TokenUpdate.shared.tokenUpdate() {
                        completion?()
                    }
                }
            }
        }
    }
}
