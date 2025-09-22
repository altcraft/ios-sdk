//
//  IOSAPNsExampleApp.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Altcraft
import HmsPushSdk
import FirebaseCore
import FirebaseMessaging

//set AppGroups identifier
let appGroup = "your_app_group_identifier"

@main
struct IOSAPNsExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var mode: Int = 1
    private let deeplinkManager = DeeplinkManager()

    var body: some Scene {
        WindowGroup {
            ContentView(mode: $mode)
                .environmentObject(GlobalTokenManager.shared)
                .environmentObject(GlobalEventManager.shared)
                .onOpenURL { url in
                    if case let .mode(m)? = deeplinkManager.manage(url: url) {
                        mode = m
                    }
                }
                .preferredColorScheme(.light)
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
//        FirebaseConfiguration.shared.setLoggerLevel(.min)
//        FirebaseApp.configure()
//        Messaging.messaging().delegate = self
        Messaging.messaging().apnsToken = getAPNsTokenDataFromUserDefaults()
       
        AltcraftSDK.shared.setAppGroup(groupName: appGroup)
        AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
        AltcraftSDK.shared.setJWTProvider(provider: JWTProvider())
        AltcraftSDK.shared.pushTokenFunction.setAPNSTokenProvider(APNSProvider())
        AltcraftSDK.shared.pushTokenFunction.setFCMTokenProvider(FCMProvider())
        AltcraftSDK.shared.pushTokenFunction.setHMSTokenProvider(HMSProvider())
        AltcraftSDK.shared.notificationManager.registerForPushNotifications(for: application)
        
        //app function
        registerAltcraftEventHandlers()

        initSDK(config: getConfigFromUserDefault())
        
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken apnsToken: Data
    ) {
        //Messaging.messaging().apnsToken = apnsToken
        setAPNsTokenInUserDefault(apnsToken)
        
        AltcraftSDK.shared.pushTokenFunction.getPushToken()
    }
}


extension AppDelegate {
    /// Registers event handlers for Altcraft SDK events.
    func registerAltcraftEventHandlers() {
        AltcraftSDK.shared.eventSDKFunctions.subscribe { event in
            // Delegate token handling to TokenManager
            Task { @MainActor in
                GlobalTokenManager.shared.updateToken(with: event)
            }
            
            // Delegate status handling to StatusManager
            Task { @MainActor in
                GlobalStatusManager.shared.updateStatus(with: event)
            }
            
            // Add event to the global event manager
            Task { @MainActor in
                GlobalEventManager.shared.addEvent(event)
            }
            
            // Add profile data to the global manager
            Task { @MainActor in
                GlobalProfileDataManager.shared.fetchProfileData(with: event)
            }
        }
    }
}


