//
//  SDKFunctions.swift
//  Example
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft

/// Initializes Altcraft SDK with configuration stored in UserDefaults.
/// If configuration is missing, initialization is skipped.
///
/// - Parameter config: App configuration containing API URL, rToken and provider list.
func initSDK(config: AppConfig?) {
    guard let config = config else { return }
    
    let rToken: String? = {
        if let token = config.rToken, !token.isEmpty {
            return token
        }
        return nil
    }()
    
    let configuration = AltcraftConfiguration.Builder()
        .setApiUrl(config.apiUrl)
        .setRToken(rToken)
        .setProviderPriorityList(config.providerNames)
        .build()
    
    AltcraftSDK.shared.initialization(configuration: configuration)
}

/// Updates push provider priority list, persists it in UserDefaults,
/// and notifies the SDK about the provider change.
///
/// - Parameter providers: Ordered list of provider identifiers to use as priority.
private func updateProviderPriorityList(_ providers: [String]) {
    if let config = getConfigFromUserDefault() {
        let updatedConfig = AppConfig(
            apiUrl: config.apiUrl,
            rToken: config.rToken,
            providerNames: providers
        )
        setConfigInUserDefaults(config: updatedConfig) { _ in
            AltcraftSDK.shared.pushTokenFunctions.changePushProviderPriorityList(providers)
        }
    } else {
        AltcraftSDK.shared.pushTokenFunctions.changePushProviderPriorityList(providers)
    }
}

/// Switches push provider priority to APNs.
func switchToAPNS() {
    updateProviderPriorityList([Constants.ProviderName.apns])
}

/// Switches push provider priority to Firebase Cloud Messaging (FCM).
func switchToFCM() {
    updateProviderPriorityList([Constants.ProviderName.firebase])
}

/// Switches push provider priority to Huawei Mobile Services (HMS).
func switchToHMS() {
    updateProviderPriorityList([Constants.ProviderName.huawei])
}

/// Performs login transition.
///
/// Updates authentication status, calls unSuspendPushSubscription,
/// and if the current JWT profile has no active subscription,
/// performs pushSubscribe() with stored settings.
func logIn() {
    JWTManager.shared.setAuthStatus(true)
    AltcraftSDK.shared.pushSubscriptionFunctions.unSuspendPushSubscription { result in
        if result?.httpCode == 200, result?.response?.profile?.subscription == nil {
            let subscriptionSetting = getSubscriptionSettingFromUserDefaults()
            
            AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
                sync: subscriptionSetting.sync,
                profileFields: subscriptionSetting.profileFields,
                customFields: subscriptionSetting.customFields,
                cats: subscriptionSetting.cats,
                replace: subscriptionSetting.replace,
                skipTriggers: subscriptionSetting.replace
            )
        }
    }
}

/// Performs logout transition.
///
/// Switches JWT to anonymous, calls unSuspendPushSubscription,
/// and if the anonymous profile has no subscription, creates a new one.
func logOut() {
    JWTManager.shared.setAuthStatus(false)
    AltcraftSDK.shared.pushSubscriptionFunctions.unSuspendPushSubscription { result in
        if result?.httpCode == 200, result?.response?.profile?.subscription == nil {
            let subscriptionSetting = getSubscriptionSettingFromUserDefaults()
            
            AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
                sync: subscriptionSetting.sync,
                profileFields: subscriptionSetting.profileFields,
                customFields: subscriptionSetting.customFields,
                cats: subscriptionSetting.cats,
                replace: subscriptionSetting.replace,
                skipTriggers: subscriptionSetting.replace
            )
        }
    }
}

/// Creates a push subscription.
/// Forwards sync, replace, skipTriggers, and custom/profile fields.
func pushSubscribe() {
    let subscriptionSetting = getSubscriptionSettingFromUserDefaults()
    
    AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
        sync: subscriptionSetting.sync,
        profileFields: subscriptionSetting.profileFields,
        customFields: subscriptionSetting.customFields,
        cats: subscriptionSetting.cats,
        replace: subscriptionSetting.replace,
        skipTriggers: subscriptionSetting.replace
    )
}

/// Suspends the current push subscription.
func pushSuspend() {
    AltcraftSDK.shared.pushSubscriptionFunctions.pushSuspend()
}

/// Unsubscribes from push using saved subscription settings.
func pushUnsubscribe() {
    let subscriptionSetting = getSubscriptionSettingFromUserDefaults()
    
    AltcraftSDK.shared.pushSubscriptionFunctions.pushUnSubscribe(
        sync: subscriptionSetting.sync,
        profileFields: subscriptionSetting.profileFields,
        customFields: subscriptionSetting.customFields,
        cats: subscriptionSetting.cats,
        replace: subscriptionSetting.replace,
        skipTriggers: subscriptionSetting.replace
    )
}
