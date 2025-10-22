//
//  PublicPushEventFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UserNotifications

/// Public API for reporting Altcraft push events such as delivery and open.
@objcMembers
public class PublicPushEventFunctions: NSObject {
    
    public static let shared = PublicPushEventFunctions()
    private var service = AltcraftPushReceiver()
    private let pushEvent = PushEvent.shared
    
    /// Reports that an Altcraft push notification was delivered to the device.
    ///
    /// - Parameters:
    ///   - request: UNNotificationRequest from didReceive
    public func deliveryEvent(from request: UNNotificationRequest) {
        guard service.isAltcraftPush(request) else { return }
        
        guard let userInfo = request.content.userInfo as? [String: Any] else {
            errorEvent(#function, error: errorHandleUserInfo)
            return
        }
        
        pushEvent.createPushEvent(userInfo: userInfo , type: Constants.PushEvents.delivery)
    }
    
    /// Reports that an Altcraft push notification was opened by the user.
    ///
    /// - Parameters:
    ///   - request: UNNotificationRequest from didReceive
    public func openEvent(from request: UNNotificationRequest) {
        guard service.isAltcraftPush(request) else { return }
        
        guard let userInfo = request.content.userInfo as? [String: Any] else {
            errorEvent(#function, error: errorHandleUserInfo)
            return
        }

        pushEvent.createPushEvent(userInfo: userInfo, type: Constants.PushEvents.open)
    }
}
