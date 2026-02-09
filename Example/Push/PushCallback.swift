//
//  PushCallback.swift
//  Example
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import Altcraft
import Foundation

/// Sets up Altcraft push callbacks.
/// Handles foreground presentation and reports an "open" event on tap.
func setupAltcraftPushCallbacks() {
    let manager = AltcraftSDK.shared.notificationManager

    manager.customPushProcessing = true
    manager.customClickProcessing = true

    manager.onForegroundNotification = { notification, complete in
        _ = notification.request.content.userInfo
        print("foreground push")
        if #available(iOS 14.0, *) {
            complete([.banner, .badge, .sound])
        } else {
            complete([.alert, .badge, .sound])
        }
    }

    manager.onNotificationClick = { response, complete in
        let request = response.notification.request
        AltcraftSDK.shared.pushEventFunctions.openEvent(from: request)
        print("push click")
        complete()
    }
}
