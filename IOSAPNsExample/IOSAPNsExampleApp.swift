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

///set AppGroups identifier
let appGroup = "your_app_group_id"

///set the JWT value for the anonymous user as anonJWT or in the application IU interface (config)
let anonJWT: String? = nil

///set the JWT value for the registered user as regJWT or in the application IU interface (config)
let regJWT: String? = nil


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

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        registerAltcraftEventHandlers()
        
        /// Firebase  functions — uncomment if GoogleService-Info.plist is added to the project.
        // FirebaseConfiguration.shared.setLoggerLevel(.min)
        // FirebaseApp.configure()
        
        //Altcraft
        AltcraftSDK.shared.setAppGroup(groupName: appGroup)
        AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
        AltcraftSDK.shared.setJWTProvider(provider: JWTProvider())
        AltcraftSDK.shared.pushTokenFunction.setFCMTokenProvider(FCMProvider())
        AltcraftSDK.shared.pushTokenFunction.setHMSTokenProvider(HMSProvider())
        AltcraftSDK.shared.pushTokenFunction.setAPNSTokenProvider(APNSProvider())
        AltcraftSDK.shared.notificationManager.registerForPushNotifications(for: application)
        
        initSDK(config: getConfigFromUserDefault())
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken apnsToken: Data
    ) {
        //APNS
        setAPNsTokenInUserDefault(apnsToken)
        AltcraftSDK.shared.pushTokenFunction.getPushToken()
    }
}

/**
 * Altcraft SDK setup on iOS
 *
 * You can configure Altcraft SDK via your app UI (Config screen) or initialize it programmatically.
 *
 * Example (programmatic init in AppDelegate):
 *
 * import Altcraft
 *
 * func application(_ application: UIApplication,
 *                  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
 *
 *     // 1) Build configuration
 *     let builder = AltcraftConfiguration_Builder()
 *         .setApiUrl("https://pxl-example.altcraft.com")
 *         // .setRToken(nil) // optional, if you use a static resource token
 *         .setProviderPriorityList([
 *             "ios-apns",     // Apple Push Notification service
 *             "ios-firebase", // Firebase on iOS
 *             "ios-huawei"    // Huawei on iOS
 *         ])
 *
 *     // Optional app metadata (use either Swift or ObjC DTO)
 *     // Swift:
 *     // let info = AppInfo(appID: "com.example.app",
 *     //                    appIID: "8b91f3a0-1111-2222-3333-c1a2c1a2c1a2",
 *     //                    appVer: "1.0.0")
 *     // builder.setAppInfo(info)
 *
 *     // Objective-C DTO:
 *     // let infoObjC = ACAppInfoObjC(appID: "com.example.app",
 *     //                              appIID: "8b91f3a0-1111-2222-3333-c1a2c1a2c1a2",
 *     //                              appVer: "1.0.0")
 *     // builder.setAppInfo(infoObjC) // ObjC-only API (hidden from Swift)
 *
 *     return true
 * }
 *
 * Notes & prerequisites:
 * - Capabilities:
 *   • Push Notifications (Signing & Capabilities)
 *   • Background Modes → “Remote notifications”
 *   • (Optional) App Groups → if you call setAppGroup(...)
 *   • (Optional) Notification Service Extension → for rich push (media, buttons)
 *
 * - Provider resources (Bundle files):
 *   • **Firebase**: add **GoogleService-Info.plist** to the main app target.
 *   • **Huawei**: add **AGConnect-Info.plist** to the main app target (required when using the "ios-huawei" provider).
 *
 * - Provider priority:
 *   The list you pass to `setProviderPriorityList([ ... ])` determines which provider is attempted first.
 *   Valid identifiers include: "ios-apns", "ios-firebase", "ios-huawei".
 *
 * - JWT:
 *   Provide a JWT via your `JWTInterface` implementation (anonymous/registered), or update it at runtime.
 *
 * - Objective-C:
 *   All the same steps are available from ObjC via the `AltcraftConfiguration_Builder`
 *   and ObjC-bridged functions/types you added (see AltcraftObjCTypes.swift).
 */
