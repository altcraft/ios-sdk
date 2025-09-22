//
//  SDKFunctions.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Altcraft


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

func switchToAPNS() {
    let providers = [
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase,
        Constants.ProviderName.huawei
    ]
    
    if let config = getConfigFromUserDefault() {
        let config = AppConfig(
            apiUrl: config.apiUrl,
            rToken: config.rToken,
            providerNames: providers
        )
        setConfigInUserDefaults(config: config) {_ in
            AltcraftSDK.shared.pushTokenFunction.changePushProviderPriorityList(providers)
        }
    } else { return }
}

func switchToFCM() {
    let providers = [
        Constants.ProviderName.firebase,
        Constants.ProviderName.apns,
        Constants.ProviderName.huawei
    ]
    
    if let config = getConfigFromUserDefault() {
        let config = AppConfig(
            apiUrl: config.apiUrl,
            rToken: config.rToken,
            providerNames: providers
        )
        setConfigInUserDefaults(config: config){_ in
            AltcraftSDK.shared.pushTokenFunction.changePushProviderPriorityList(providers)
        }
    } else { return }
}

func switchToHMS() {
    let providers = [
        Constants.ProviderName.huawei,
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase
    ]
    
    if let config = getConfigFromUserDefault() {
        let config = AppConfig(
            apiUrl: config.apiUrl,
            rToken: config.rToken,
            providerNames: providers
        )
        setConfigInUserDefaults(config: config){_ in
            AltcraftSDK.shared.pushTokenFunction.changePushProviderPriorityList(providers)
        }
    } else { return }
}


func logIn() {
    JWTManager.shared.setJWT(JWTManager.shared.getRegJWT())
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

func logOut() {
    
    JWTManager.shared.setJWT(JWTManager.shared.getAnonJWT())
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

func pushSuspend() {
    AltcraftSDK.shared.pushSubscriptionFunctions.pushSuspend()
}


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
