//
//  NotificationService.swift
//  PushService
//
//  Created by andrey on 18.07.2025.
//

import Altcraft
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var service = AltcraftPushReceiver()
    
    /// - important! Set app groups name.
    var appGroupsName = "your_app_group_identifier"
    let jwtProvider = JWTProvider()

    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        AltcraftSDK.shared.setAppGroup(groupName: appGroupsName)
        AltcraftSDK.shared.setJWTProvider(provider: jwtProvider)
    
        
        //testSendMessage(request: request)
        
        if service.isAltcraftPush(request) {
            self.service.didReceive(request, withContentHandler: contentHandler)
        } else {
            contentHandler(request.content)
        }
    }
    override func serviceExtensionTimeWillExpire() { service.serviceExtensionTimeWillExpire() }
}

