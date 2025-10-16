//
//  NotificationServiceFunction.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UserNotifications
import UIKit

/// The `NotificationManager` contains iOS system hooks for receiving and handling remote push notifications.
///
/// ObjC support:
/// - Use `[NotificationManager shared]` (or `[NotificationManager sharedInstance]`) to access the singleton.
/// - Methods are exposed to Objective-C via `@objcMembers`.
@objcMembers
public class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    /// Shared singleton instance.
    /// Swift: `NotificationManager.shared`
    /// ObjC:  `[NotificationManager shared]` or `[NotificationManager sharedInstance]`
    public static let shared = NotificationManager()
    
    /// Optional Objective-C friendly accessor (identical to `shared`).
    public class func sharedInstance() -> NotificationManager { NotificationManager.shared }
    
    private let pushEvent = PushEvent.shared

    /// Registers the app for push notifications.
    ///
    /// Sets the `UNUserNotificationCenter` delegate, requests authorization for alerts/sounds/badges,
    /// and registers with APNs. Completion is invoked with the user's authorization decision.
    ///
    /// - Parameters:
    ///   - application: The `UIApplication` instance used to register for remote notifications.
    ///   - completion: Optional closure/block called with `(granted, error)`.
    ///                 ObjC signature: `void (^)(BOOL granted, NSError * _Nullable error)`
    public func registerForPushNotifications(
        for application: UIApplication,
        completion: ((_ granted: Bool, _ error: Error?) -> Void)? = nil
    ) {
        UNUserNotificationCenter.current().delegate = self
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in
                if Thread.isMainThread {
                    application.registerForRemoteNotifications()
                } else {
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
                completion?(granted, error)
            }
        }
    }
    
    /// Foreground presentation handler.
    ///
    /// Called when a notification arrives while the app is in the foreground.
    /// Customize the presentation options as needed.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    /// User response handler (tap/action on a delivered notification).
    ///
    /// Triggers a `"open"` push event and runs `pushClickAction` to process custom actions.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let userInfo = response.notification.request.content.userInfo as? [String: AnyObject] {
            pushEvent.createPushEvent(userInfo: userInfo, type: Constants.PushEvents.open)
            pushClickAction(userInfo: userInfo, identifier: response.actionIdentifier)
        }
        completionHandler()
    }
}

