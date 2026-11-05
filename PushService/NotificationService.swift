//
//  NotificationService.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import UserNotifications
import AltcraftCore
import AltcraftPush
import AltcraftTarget
import AltcraftProfile

/// Notification Service Extension for rich push processing.
class NotificationService: UNNotificationServiceExtension {
    
    /// - important! Set app groups identifier.
    let appGroupID = "group.altcraft.example"
    
    /// - important! Set the provider to JWT if you are using JWT authentication.
    let jwtProvider = JWTProvider()
    
    /// Processes the incoming push: downloads rich media, applies action
    /// buttons and delivers the modified content.
    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        AltcraftNSE.setAppGroup(groupName: appGroupID)
        AltcraftNSE.setJWTProvider(provider: jwtProvider)

        if AltcraftNSE.isAltcraftPush(request) {
            AltcraftNSE.handleNotificationRequest(
                request: request,
                contentHandler: contentHandler
            )
        } else {
            contentHandler(request.content)
        }
    }
    /// Delivers the best-available content when the extension runtime
    /// is about to expire.
    override func serviceExtensionTimeWillExpire() {
        AltcraftNSE.serviceExtensionTimeWillExpire()
    }
}
