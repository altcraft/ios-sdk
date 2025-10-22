//
//  NotificationService.swift
//  PushService
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Altcraft
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var service = AltcraftPushReceiver()
    
    /// - important! Set app groups identifier.
    var appGroupID = "your.app.group.id"
    let jwtProvider = JWTProvider()

    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        AltcraftSDK.shared.setAppGroup(groupName: appGroupID)
        AltcraftSDK.shared.setJWTProvider(provider: jwtProvider)
        
        if service.isAltcraftPush(request) {
            self.service.didReceive(request, withContentHandler: contentHandler)
        } else {
            contentHandler(request.content)
        }
    }
    override func serviceExtensionTimeWillExpire() { service.serviceExtensionTimeWillExpire() }
}
