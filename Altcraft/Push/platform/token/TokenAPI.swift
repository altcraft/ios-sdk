//
//  TokenAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public interface for setting push token providers (FCM, HMS, APNs)
/// and working with tokens from Swift/Objective-C.
@objcMembers
@objc(PublicPushTokenFunctions)
@available(iOSApplicationExtension, unavailable)
public final class TokenAPI: NSObject, @unchecked Sendable {

    /// Shared singleton instance.
    public static let shared: TokenAPI = {
        Push.ensureRegistered()
        return TokenAPI()
    }()
    private let tokenManager = TokenManager.shared

    /// Sets the Firebase Cloud Messaging (FCM) token provider.
    ///
    /// - Parameter provider: The `FCMInterface` implementation to be used, or `nil` to unset it.
    public func setFCMTokenProvider(_ provider: FCMInterface?) {
        let providerBox = UncheckedSendableBox(provider)
        let manager = tokenManager

        Task {
            await manager.setFCMProvider(providerBox.value)
        }
    }

    /// Sets the Huawei Mobile Services (HMS) token provider.
    ///
    /// - Parameter provider: The `HMSInterface` implementation to be used, or `nil` to unset it.
    public func setHMSTokenProvider(_ provider: HMSInterface?) {
        let providerBox = UncheckedSendableBox(provider)
        let manager = tokenManager

        Task {
            await manager.setHMSProvider(providerBox.value)
        }
    }

    /// Sets the Apple Push Notification Service (APNs) token provider.
    ///
    /// - Parameter provider: The `APNSInterface` implementation to be used, or `nil` to unset it.
    public func setAPNSTokenProvider(_ provider: APNSInterface?) {
        let providerBox = UncheckedSendableBox(provider)
        let manager = tokenManager

        Task {
            await manager.setAPNSProvider(providerBox.value)
        }
    }

    /// Asynchronously retrieves the current push token.
    ///
    /// - Parameter completion: Called on the main thread with `TokenData?`.
    @nonobjc
    public func getToken(
        completion: (@Sendable (TokenData?) -> Void)? = nil
    ) {
        Task {
            let tokenData = await tokenManager.getCurrentToken()
            guard let completion else { return }

            await MainActor.run {
                completion(tokenData)
            }
        }
    }

    /// ObjC-only: asynchronously retrieves the current push token as `TokenDataObjC`.
    ///
    /// Selector (ObjC): `getPushToken:`
    ///
    /// - Parameter completion: Called on the main thread with `TokenDataObjC?`.
    @available(swift, obsoleted: 1)
    @objc(getPushToken:)
    public func getPushTokenObjC(_ completion: ((TokenDataObjC?) -> Void)? = nil) {
        let completionBox = completion.map { CallbackBox<TokenDataObjC?>($0) }

        Task { [completionBox] in
            let tokenData = await tokenManager.getCurrentToken()
            let bridged = TokenDataObjC.from(tokenData)

            guard let completionBox else { return }

            await MainActor.run {
                completionBox.call(bridged)
            }
        }
    }

    /// Saves or clears a manual push token.
    ///
    /// - Parameters:
    ///   - provider: One of: `"ios-firebase"`, `"ios-huawei"`, `"ios-apns"`.
    ///   - pushToken: `String` (FCM/HMS) or `Data` (APNs). Pass `nil` to clear.
    public func setToken(provider: String, pushToken: Any?) {
        guard tokenManager.allProvidersValid([provider]) else {
            PushLog.error(
                #function,
                error: PushModuleEvents.invalidPushProviders,
                eventValue: [PushConstants.MapKeys.provider: provider]
            )
            return
        }

        let token: String? =
            (pushToken as? String) ??
            (pushToken as? Data).map { data in
                data.map { String(format: "%02x", $0) }.joined()
            }

        Task {
            await PushStoredVariables.shared.setPushToken(
                provider: provider,
                token: token
            )
        }
    }

    /// Updates the provider priority list in the push module configuration and triggers token update.
    ///
    /// - Parameter list: Array of provider identifiers.
    public func changeProviderPriority(_ list: [String]) {
        guard tokenManager.allProvidersValid(list) else {
            PushLog.error(#function, error: PushModuleEvents.invalidPushProviders)
            return
        }
        
        Task {
            await PushConfigManager.shared.setConfig(
                PushConfiguration(providerPriority: list)
            )
            
            _ = await PushTokenWorker.shared.processPending()
        }
    }

    /// Forces a token refresh by deleting the current token (if supported)
    /// and then starting the token update flow.
    ///
    /// For APNs, deletion/refresh is not supported; an error is logged and the flow ends.
    ///
    /// - Parameter completion: Called when the flow finishes.
    ///                         Delivered on the main thread.
    @nonobjc
    public func forcedTokenUpdate(
        completion: (@Sendable () -> Void)? = nil
    ) {
        Task {
            guard let tokenData = await tokenManager.getCurrentToken() else {
                PushLog.error(#function, error: PushModuleEvents.pushTokenIsNil)
                if let completion {
                    await MainActor.run {
                        completion()
                    }
                }
                return
            }

            let provider = tokenData.provider

            if provider == PushConstants.ProviderName.apns {
                PushLog.error(#function, error: PushModuleEvents.apnsIsNotUpdated)
                if let completion {
                    await MainActor.run {
                        completion()
                    }
                }
                return
            }

            self.deleteToken(provider: provider) {
                Task {
                    _ = await PushTokenWorker.shared.processPending()

                    if let completion {
                        await MainActor.run {
                            completion()
                        }
                    }
                }
            }
        }
    }

    /// Performs provider-specific token deletion.
    ///
    /// For APNs, deletion is not supported and only an error is logged.
    ///
    /// - Parameter provider: Provider identifier.
    @nonobjc
    public func deleteToken(
        provider: String,
        completion: (@Sendable () -> Void)? = nil
    ) {
        let normalized = provider.lowercased()

        switch normalized {
        case PushConstants.ProviderName.firebase:
            Task {
                await tokenManager.deleteFCMToken { _ in
                    guard let completion else { return }

                    Task {
                        await MainActor.run {
                            completion()
                        }
                    }
                }
            }

        case PushConstants.ProviderName.huawei:
            Task {
                await tokenManager.deleteHMSToken { _ in
                    guard let completion else { return }

                    Task {
                        await MainActor.run {
                            completion()
                        }
                    }
                }
            }

        case PushConstants.ProviderName.apns:
            PushLog.error(#function, error: PushModuleEvents.apnsIsNotUpdated)
            if let completion {
                Task {
                    await MainActor.run {
                        completion()
                    }
                }
            }

        default:
            PushLog.error(#function, error: PushModuleEvents.invalidPushProviders)
            if let completion {
                Task {
                    await MainActor.run {
                        completion()
                    }
                }
            }
        }
    }
}
