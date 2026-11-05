//
//  EventAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UserNotifications

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public API for reporting Altcraft push events such as delivery and open.
@objcMembers
@objc(PublicPushEventFunctions)
public final class EventAPI: NSObject, @unchecked Sendable {

    public static let shared: EventAPI = {
        Push.ensureRegistered()
        return EventAPI()
    }()
    private let receiver = AltcraftPushReceiver()
    private let pushEvent = PushEventProcess.shared

    /// Reports that an Altcraft push notification was delivered to the device.
    ///
    /// - Parameter request: `UNNotificationRequest` from notification callbacks.
    public func deliveryEvent(from request: UNNotificationRequest) {
        handlePushEvent(
            from: request, type: PushConstants.PushEvents.delivery
        )
    }

    /// Reports that an Altcraft push notification was opened by the user.
    ///
    /// - Parameter request: `UNNotificationRequest` from notification callbacks.
    public func openEvent(from request: UNNotificationRequest) {
        handlePushEvent(
            from: request, type: PushConstants.PushEvents.open
        )
    }

    /// Validates an Altcraft push request, extracts its `uid`, and schedules push event creation.
    ///
    /// - Parameters:
    ///   - request: The notification request to inspect.
    ///   - type: The push event type to create.
    private func handlePushEvent(from request: UNNotificationRequest, type: String) {
        guard receiver.isAltcraftPush(request) else { return }

        let uid = request.content.userInfo[PushConstants.UserInfoKeys.uid]
        as? String

        Task {
            await self.pushEvent.createPushEvent(uid: uid, type: type)
        }
    }
}
