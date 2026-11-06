//
//  Example.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
import SwiftUI
import FirebaseCore
import FirebaseMessaging

import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget

/// App Group identifier used by the main application and extensions.
let appGroupID = "group.altcraft.example"

/// JWT value for the anonymous user.
///
/// Can also be configured through the application UI.
let anonJWT: String? = nil

/// JWT value for the registered user.
///
/// Can also be configured through the application UI.
let regJWT: String? = nil
/// Example application entry point.
@main
struct IOSAPNsExampleApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else {
                return
            }
        }
    }
}

// MARK: - AppDelegate
/// Application delegate performing the Altcraft SDK setup.
class AppDelegate: UIResponder,
                   UIApplicationDelegate,
                   UNUserNotificationCenterDelegate {
    
    /// Performs application startup configuration.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Skip the demo SDK setup when running unit tests in this host
        // application: registering providers and initializing the SDK would
        // persist configuration into the shared in-memory stores, hit the
        // real network, and pollute the test process state.
        if NSClassFromString("XCTestCase") != nil {
            // Background task identifiers must still be registered with the
            // system even under tests: otherwise BGTaskScheduler.submit
            // raises an uncatchable exception when a test initializes
            // the SDK and schedules a refresh.
            AltcraftSDK.backgroundTasks.registerBackgroundTask()
            return true
        }

        registerAltcraftEventHandlers()
        
        /// Registers lifecycle tracking used by In-App campaigns.
        AltcraftSDK.inApp.registerLifecycleTracking()
        
        /// Configures the App Group used by the SDK.
        AltcraftSDK.setAppGroup(groupName: appGroupID)
    
        /// Registers SDK background tasks.
        AltcraftSDK.backgroundTasks.registerBackgroundTask()

        // MARK: Firebase
        
        /// Firebase functions.
        ///
        /// Requires GoogleService-Info.plist to be added
        /// to the main application target.
        //FirebaseConfiguration.shared.setLoggerLevel(.min)
        //FirebaseApp.configure()

        /// Sets the JWT provider used by the SDK.
        AltcraftSDK.auth.setJWTProvider(
            provider: JWTProvider()
        )
    
        /// Registers Firebase Cloud Messaging token provider.
        AltcraftSDK.push.token.setFCMTokenProvider(
            FCMProvider()
        )
        
        /// Registers Huawei Mobile Services token provider.
        ///
        /// Uncomment when HMS is configured.
        // AltcraftSDK.push.token.setHMSTokenProvider(
        //     HMSProvider()
        // )
        
        /// Registers Apple Push Notification Service token provider.
        AltcraftSDK.push.token.setAPNSTokenProvider(
            APNSProvider()
        )
        
        /// Requests push notification permissions and registers
        /// the application for remote notifications.
        AltcraftSDK.push.notificationManager.registerForPushNotifications(
            for: application
        )

        // MARK: SDK initialization
       initSDK(config: getConfigFromUserDefault())
        
        return true
    }

    // MARK: APNs
    
    /// Called after successful registration with APNs.
    //
    /// The received APNs device token is stored and then passed
    /// to the Altcraft push token subsystem.
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken apnsToken: Data
    ) {
        
        /// Store APNs token in UserDefaults.
        setAPNsTokenInUserDefault(apnsToken)
        
        /// Ask Altcraft SDK to obtain and process the current push token.
        AltcraftSDK.push.token.getToken()
    }
}

/**
 * Altcraft SDK setup on iOS
 *
 * The SDK can also be configured through the application UI (Config).
 *
 * Usage:
 * ```swift
 * let config = AltcraftConfiguration.Builder(
 *     apiUrl: "https://pxl-example.altcraft.com",
 *     rToken: nil,
 *     appInfo: AppInfo(
 *         appID: "com.example.app",
 *         appIID: "8b91f3a0-1111-2222-3333-c1a2c1a2c1a2",
 *         appVer: "1.0.0"
 *     )
 * )
 *     .pushConfig(
 *         providerPriority: [
 *             "ios-apns",
 *             "ios-firebase",
 *             "ios-huawei"
 *         ]
 *     )
 *     .inAppConfig(
 *         inAppAutoRequest: true,
 *         placementsRequestInterval: .init(value: 10, unit: .minutes),
 *         maxPlacements: 10
 *     )
 *     .build()
 *
 * AltcraftSDK.initialization(configuration: config)
 * ```
 *
 * Objective-C:
 * ```objc
 * AppInfoObjC *info = [[AppInfoObjC alloc]
 *     initWithAppID:@"com.example.app"
 *             appIID:@"8b91f3a0-1111-2222-3333-c1a2c1a2c1a2"
 *            appVer:@"1.0.0"];
 *
 * AltcraftConfiguration_Builder *builder = [[AltcraftConfiguration_Builder alloc]
 *     initWithApiUrl:@"https://pxl-example.altcraft.com"
 *             rToken:nil
 *            appInfo:info
 *      enableLogging:YES];
 * ```
 *
 * Provider resources (main application target root):
 * - "ios-firebase" — add GoogleService-Info.plist
 * - "ios-huawei"   — add AGConnect-Info.plist
 *
 * Capabilities:
 * - Push Notifications
 * - Background Modes → Remote notifications
 * - App Groups — required for AltcraftSDK.setAppGroup(...) and the
 *   Notification Service Extension (optional, rich push)
 *
 * JWT — provide tokens through a JWTInterface implementation
 * (getToken() -> String?) for anonymous and/or registered users.
 *
 * App Tracking Transparency — to access IDFA on iOS 14.5+, add the
 * "Privacy - Tracking Usage Description" key (NSUserTrackingUsageDescription)
 * to the main application target Info.plist.
 *
 * Full documentation: README.md → Documentation.
 */

