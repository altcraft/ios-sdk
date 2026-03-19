//
//  AltcraftPushReceiver.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

@preconcurrency import UserNotifications
import Foundation

/// Handles Altcraft push notifications inside a Notification Service Extension.
/// Responsible for: delivery event tracking, action button creation,
/// category registration, and media attachment loading.
@objcMembers
final class AltcraftPushReceiver: NSObject, @unchecked Sendable {

    private var handler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    

    /// Checks whether a push notification belongs to Altcraft.
    ///
    /// - Parameter request: The incoming `UNNotificationRequest`.
    /// - Returns: `true` if the push contains Altcraft signature fields, otherwise `false`.
    func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        (request.content.userInfo as? [String: Any])?["_ac_push"] != nil
    }

    /// Processes an Altcraft push inside the NSE: records delivery event,
    /// attaches media, creates categories and actions, and returns final content.
    ///
    /// - Parameters:
    ///   - request: The notification request received by NSE.
    ///   - handler: Completion handler invoked with modified content.
    func takePush(
        _ request: UNNotificationRequest,
        withContentHandler handler: @escaping (UNNotificationContent) -> Void
    ) {
        self.handler = handler
        self.content = request.content.mutableCopy()
        as? UNMutableNotificationContent

        guard content != nil else { return handler(request.content) }
        
        Task {
            let type = Constants.PushEvents.delivery
            
            let uid = request.content.userInfo[
                Constants.UserInfoKeys.uid
            ] as? String
        
            await PushEvent.shared.createPushEvent(
                uid: uid, type:type
            )
            
            makeCategory(from: request.content.userInfo)
            
            let notificationContent = await loadNotificationImage(
                for: request
            )
            
            event(#function, event: pushIsPosted)
            self.handler?(notificationContent)
        }
    }

    /// Creates a notification category with interactive buttons extracted from push payload.
    ///
    /// - Parameter info: `userInfo` dictionary from push.
    private func makeCategory(from info: [AnyHashable: Any]) {
        let categoryKey = Constants.categoryForRichPush
        var actions: [UNNotificationAction] = []

        if
            let json = info[Constants.UserInfoKeys.buttons] as? String,
            let data = json.data(using: .utf8),
            let arr = try? JSONDecoder().decode([[String: String]].self, from: data)
        {
            actions = arr.enumerated().compactMap { index, btn in
                guard let title = btn["label"] else { return nil }
                return UNNotificationAction(
                    identifier: "button\(index)",
                    title: title,
                    options: [.foreground]
                )
            }
        }

        let category = UNNotificationCategory(
            identifier: categoryKey,
            actions: actions,
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        content?.categoryIdentifier = Constants.categoryForRichPush
    }

    /// Loads a remote image specified in the notification payload and
    /// attaches it to the mutable notification content.
    ///
    /// - Parameter req: The original notification request containing the media URL in `userInfo`.
    /// - Returns: Final notification content with or without image attachment.
    private func loadNotificationImage(
        for req: UNNotificationRequest
    ) async -> UNNotificationContent {
        let media = (req.content.userInfo as? [String: Any])?[
            Constants.UserInfoKeys.media
        ] as? String

        guard
            let media, let url = URL(string: media), let content = self.content
        else {
            return self.content ?? req.content
        }

        do {
            let request = URLRequest(url: url)
            let (data, _) = try await URLSession.shared.dataAsync(
                for: request
            )

            guard !data.isEmpty else {
                errorEvent(#function, error: errorMediaDownload)
                return self.content ?? content
            }

            try self.applyImageAttachment(from: data, to: content)
            return self.content ?? content
        } catch {
            errorEvent(#function, error: error)
            return self.content ?? content
        }
    }

    /// Builds and attaches image attachment to the mutable notification content.
    ///
    /// - Parameters:
    ///   - data: Downloaded image data.
    ///   - content: Mutable notification content to update with attachment.
    /// - Throws: File / Data / UNNotificationAttachment errors.
    func applyImageAttachment(
        from data: Data,
        to content: UNMutableNotificationContent
    ) throws {
        let format = ImageFormat(data: data)
        let ext = format?.fileExtension ?? "jpg"

        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(
                UUID().uuidString, isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )

        let dest = dir.appendingPathComponent("image.\(ext)")
        try data.write(to: dest)

        let options = format?.utiHint.map {
            [UNNotificationAttachmentOptionsTypeHintKey: $0]
        }

        let att = try UNNotificationAttachment(
            identifier: "img", url: dest, options: options
        )

        content.attachments = [att]
        self.content = content
    }
    
    /// Called by the system when the NSE execution time is about to expire.
    /// Returns the best content currently available.
    func serviceExtensionTimeWillExpire() {
        if let handler, let content { handler(content) }
    }
}
