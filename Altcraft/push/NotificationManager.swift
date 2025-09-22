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

/// The `NotificationServiceFunction` class contains the iOS system functions necessary to receive remote push notifications.
public class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    
    /// Shared instance of `NotificationServiceFunction`.
    internal static let shared = NotificationManager()
    private let pushEvent = PushEvent.shared

    /// Registers the application to receive push notifications.
    ///
    /// Sets the `UNUserNotificationCenter` delegate, registers for remote notifications,
    /// and requests user authorization for alerts, sounds, and badges.
    ///
    /// - Parameter application: The `UIApplication` instance used to register for notifications.
    public func registerForPushNotifications(
         for application: UIApplication,
         completion: ((_ granted: Bool, _ error: Error?) -> Void)? = nil
     ) {
         UNUserNotificationCenter.current().delegate = self
         DispatchQueue.main.async {
             UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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
    
    /// Handles the presentation of push notifications while the app is in the foreground.
    ///
    /// Called when a notification is about to be shown while the app is active.
    /// Use the `completionHandler` to specify how the notification should be presented—e.g., with banner, badge, or sound.
    ///
    /// - Parameters:
    ///   - center: The `UNUserNotificationCenter` that received the notification.
    ///   - notification: The `UNNotification` to be presented.
    ///   - completionHandler: A closure that takes `UNNotificationPresentationOptions` to define how to display the notification.
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

    /// Handles the user's response to a delivered notification.
    ///
    /// This function is triggered after the user taps on the notification.
    /// It is responsible for triggering  push event  `"open"` and invoking `pushClickAction()` to process any custom actions.
    ///
    /// - Parameters:
    ///   - center: The `UNUserNotificationCenter` that received the response.
    ///   - response: The user’s response to the notification.
    ///   - completionHandler: The block to execute when the response has been processed.
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
