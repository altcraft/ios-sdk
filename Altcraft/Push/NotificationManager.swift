//
//  NotificationManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
@preconcurrency import UserNotifications
import UIKit

public extension Notification.Name {
    /// Fired when a notification is about to be presented in foreground.
    /// userInfo:
    ///   - "notification": UNNotification
    static let altcraftPushWillPresent = Notification.Name(
        Constants.NotificationCenter.pushWillPresent
    )

    /// Fired when user taps on a delivered notification or performs an action.
    /// userInfo:
    ///   - "response": UNNotificationResponse
    static let altcraftPushDidReceive = Notification.Name(
        Constants.NotificationCenter.pushDidReceiveResponse
    )
}

/// The `NotificationManager` contains iOS system hooks for receiving and handling remote push notifications.
///
/// ObjC support:
/// - Use `[NotificationManager shared]` (or `[NotificationManager sharedInstance]`) to access the singleton.
/// - Methods are exposed to Objective-C via `@objcMembers`.
@objcMembers
@available(iOSApplicationExtension, unavailable)
public final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    /// Shared singleton instance.
    /// Swift: `NotificationManager.shared`
    /// ObjC:  `[NotificationManager shared]` or `[NotificationManager sharedInstance]`
    public static let shared = NotificationManager()

    private let pushEvent = PushEvent.shared
    private let pushAction = PushAction.shared

    /// Optional Objective-C friendly accessor (identical to `shared`).
    /// - Returns: Shared `NotificationManager` instance.
    public class func sharedInstance() -> NotificationManager {
        NotificationManager.shared
    }

    /// When `true`, SDK delegates foreground presentation to the app.
    public var customPushProcessing: Bool = false

    /// When `true`, SDK delegates click processing to the app.
    public var customClickProcessing: Bool = false

    /// Called when a foreground push arrives.
    ///
    /// App must call `completion` when `customPushProcessing` is `true`.
    ///
    /// - Parameters:
    ///   - notification: Incoming `UNNotification`.
    ///   - completion: Completion to be called with desired presentation options.
    @nonobjc public var onForegroundNotification: (
        (UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void
    )?

    /// Called when the user taps a notification.
    ///
    /// App must call `completion` when `customClickProcessing` is `true`.
    ///
    /// - Parameters:
    ///   - response: `UNNotificationResponse` describing the user action.
    ///   - completion: Completion to be called when click handling is finished.
    @nonobjc public var onNotificationClick: (
        (UNNotificationResponse, @escaping () -> Void) -> Void
    )?

    /// Registers the app for push notifications.
    ///
    /// Sets the `UNUserNotificationCenter` delegate, requests authorization for alerts/sounds/badges,
    /// and registers with APNs.
    ///
    /// - Parameters:
    ///   - application: `UIApplication` instance used to register for remote notifications.
    ///   - completion: Optional callback with `granted` flag and optional error.
    public func registerForPushNotifications(
        for application: UIApplication,
        completion: ((_ granted: Bool, _ error: Error?) -> Void)? = nil
    ) {
        let completionBox = completion.map {
            CallbackBox<(Bool, Error?)>($0)
        }

        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
                completionBox?.call((granted, error))
            }
        }
    }

    /// Foreground presentation handler.
    ///
    /// Called when a notification arrives while the app is in the foreground.
    /// Presents as `.banner` (iOS 14+); on earlier versions uses `.alert`.
    ///
    /// - Parameters:
    ///   - center: The current `UNUserNotificationCenter`.
    ///   - notification: The incoming `UNNotification`.
    ///   - completionHandler: Call with desired `UNNotificationPresentationOptions`.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (
            UNNotificationPresentationOptions
        ) -> Void
    ) {
        NotificationCenter.default.post(
            name: .altcraftPushWillPresent,
            object: self,
            userInfo: [
                Constants.NotificationCenter.notificationKey: notification
            ]
        )

        if customPushProcessing {
            if let handler = onForegroundNotification {
                handler(notification, completionHandler)
            } else {
                completionHandler([])
            }
            return
        }

        if let handler = onForegroundNotification {
            handler(notification, { _ in })
        }

        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }

    /// Handles user interaction with a delivered notification
    /// (tap or action button).
    ///
    /// Posts `.altcraftPushDidReceive`, processes the click,
    /// records an `"open"` push event, and calls `completionHandler`
    /// when processing finishes unless custom handling is enabled.
    ///
    /// - Parameters:
    ///   - center: The `UNUserNotificationCenter`.
    ///   - response: The user's response to the notification.
    ///   - completionHandler: Must be called when processing is complete.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NotificationCenter.default.post(
            name: .altcraftPushDidReceive,
            object: self,
            userInfo: [
                Constants.NotificationCenter.responseKey: response
            ]
        )
        
        if customClickProcessing {
            if let handler = onNotificationClick {
                handler(response, completionHandler)
            } else {
                completionHandler()
            }
            return
        }
        
        let completionBox = ClosureBox(completionHandler)
        if let handler = onNotificationClick { handler(response, {}) }
       
        Task { [ completionBox] in

            await handleNotificationResponse(
                response: response, completionBox: completionBox
            )
        }
    }
    
    
    /// Processes a notification click.
    ///
    /// Extracts payload fields, runs the click action,
    /// records the `"open"` push event, and invokes
    /// the completion handler on the main thread.
    private func handleNotificationResponse(
        response: UNNotificationResponse,
        completionBox: ClosureBox
    ) async {
        let identifier = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        
        let uid = info[ Constants.UserInfoKeys.uid ] as? String
        let url = info[ Constants.UserInfoKeys.clickUrl] as? String
        let buttons = info[ Constants.UserInfoKeys.buttons ] as? String
        
        await pushAction.pushClickAction(
            buttonsJSON: buttons, clickURL: url, identifier: identifier
        )

        await pushEvent.createPushEvent(
            uid: uid, type: Constants.PushEvents.open
        )
        
        await MainActor.run { completionBox.invoke() }
    }
}
