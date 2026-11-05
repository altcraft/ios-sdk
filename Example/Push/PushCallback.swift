//
//  PushCallback.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget

/// Sets up Altcraft push callbacks.
/// Handles foreground presentation and reports an "open" event on tap.
func setupAltcraftPushCallbacks() {
    let manager = AltcraftSDK.push.notificationManager

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
        AltcraftSDK.push.pushEvents.openEvent(from: request)
        print("push click")
        complete()
    }
}
