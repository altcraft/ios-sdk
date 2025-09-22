//
//  AltcraftNotificationService.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import Foundation
import UIKit
import UserNotifications
import UserNotificationsUI

/// `AltcraftNotificationService` class responsible for displaying rich push notifications.
@objcMembers
public class AltcraftPushReceiver: NSObject {
    
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private let pushEvent = PushEvent.shared
    
    /// Determines if a notification request is related to an Altcraft push notification.
    ///
    /// - Parameter request: The `UNNotificationRequest` to check.
    /// - Returns: `true` if the notification is an Altcraft push notification; otherwise, `false`.
    public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool {
        (request.content.userInfo as? [String: Any])?["_ac_push"] != nil
    }
    
    /// Handles incoming push notification request
    /// - Parameters:
    ///   - request: The notification request containing content
    ///   - contentHandler: Completion handler to call with modified content
    public func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        event(#function, event: pushReceive)
        guard let userInfo = request.content.userInfo as? [String: Any] else {
            errorEvent(#function, error: errorHandleUserInfo)
            contentHandler(request.content)
            return
        }
        handleUserInfo(userInfo, contentHandler: contentHandler, request: request)
    }
    
    /// Processes notification user info and prepares notification content
    /// - Parameters:
    ///   - userInfo: Dictionary containing push notification data
    ///   - contentHandler: Completion handler for final notification content
    ///   - request: Original notification request
    private func handleUserInfo(
        _ userInfo: [String: Any],
        contentHandler: @escaping (UNNotificationContent) -> Void,
        request: UNNotificationRequest) {
            
            pushEvent.createPushEvent(userInfo: userInfo, type: Constants.PushEvents.delivery)
            
            let actions = createNotificationActions(from: userInfo)
            
            let simpleCategory = UNNotificationCategory(
                identifier: Constants.categoryForRichPush,
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
            
            UNUserNotificationCenter.current().setNotificationCategories([simpleCategory])
            
            self.contentHandler = { content in
                event(#function, event: pushIsPosted)
                contentHandler(content)
            }
            
            bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
            bestAttemptContent?.categoryIdentifier = Constants.categoryForRichPush
            
            guard userInfo[Constants.UserInfoKeys.media] != nil else {
                self.contentHandler?(bestAttemptContent ?? request.content)
                return
            }
            
            request.loadAttachmentAsync { [weak self] content in
                self?.contentHandler?(content)
            }
        }
    
    /// Creates notification actions from user info buttons
    /// - Parameter userInfo: Dictionary containing push notification data
    /// - Returns: Array of configured notification actions
    private func createNotificationActions(from userInfo: [String: Any]) -> [UNNotificationAction] {
        guard let buttonsJSON = userInfo[Constants.UserInfoKeys.buttons] as? String,
              let buttonsData = buttonsJSON.data(using: .utf8),
              let buttonDictionaries = try? JSONDecoder().decode([[String: String]].self, from: buttonsData)
        else {
            errorEvent(#function, error: errorButtonsKeyMissing)
            return []
        }
        
        return buttonDictionaries.enumerated().compactMap { index, button in
            guard let title = button["label"] else { return nil }
            return UNNotificationAction(
                identifier: "button\(index)",
                title: title,
                options: [.foreground]
            )
        }
    }
    
    /// Called when the service extension is about to time out
    /// Delivers the best attempt content available
    public func serviceExtensionTimeWillExpire() {
        contentHandler?(bestAttemptContent ?? UNMutableNotificationContent())
    }
    
    /// Adds a notification attachment to mutable content by moving a temporary file
    /// - Parameters:
    ///   - content: Mutable notification content to modify
    ///   - tempURL: Source file location (will be moved)
    ///   - directory: Destination directory for the attachment
    /// - Note: Silently handles errors by logging them via `errorEvent`
    func addAttachment(to content: UNMutableNotificationContent, from tempURL: URL, in directory: URL) {
        do {
            content.attachments = [try createNotificationAttachment(from: tempURL, in: directory)]
        } catch {
            errorEvent(#function, error: error)
        }
    }
    
    /// Prepares notification content and temporary directory
    /// - Parameter content: Original notification content
    /// - Returns: Tuple containing mutable content and temporary directory URL
    func prepareNotificationContent(content: UNNotificationContent) -> (UNMutableNotificationContent, URL) {
        return (
            (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent(),
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        )
    }
    
    /// Extracts media URL from notification content
    /// - Returns: URL if valid media URL exists, nil otherwise
    func extractMediaURL(content: UNNotificationContent) -> URL? {
        guard let userInfo = content.userInfo as? [String: Any],
              let imageURLString = userInfo[Constants.UserInfoKeys.media] as? String,
              let attachmentURL = URL(string: imageURLString) else {
            errorEvent(#function, error: errorMediaKeyMissing)
            return nil
        }
        return attachmentURL
    }
    
    /// Creates a UNNotificationAttachment from a temp image file, preserving its format.
    /// - Parameters:
    ///   - tempURL: Location of the downloaded/temporary image file.
    ///   - directory: Target directory where the attachment file will be moved.
    /// - Throws: File system or attachment creation errors.
    /// - Returns: A configured `UNNotificationAttachment` with a format-appropriate filename.
    func createNotificationAttachment(
        from tempURL: URL,
        in directory: URL
    ) throws -> UNNotificationAttachment {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        let data = try Data(contentsOf: tempURL, options: .mappedIfSafe)
        let detected = ImageFormat(data: data)
        
        let fallbackExt = tempURL.pathExtension.isEmpty ? "jpg" : tempURL.pathExtension.lowercased()
        let ext = detected?.fileExtension ?? fallbackExt
        
        let filename = "attachment-\(UUID().uuidString).\(ext)"
        let destURL = directory.appendingPathComponent(filename, isDirectory: false)
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        
        var options: [String: Any]? = nil
        if let hint = detected?.utiHint {
            options = [UNNotificationAttachmentOptionsTypeHintKey: hint]
        }
        
        return try UNNotificationAttachment(identifier: "image-\(ext)", url: destURL, options: options)
    }
}

extension UNNotificationRequest {
    /// Asynchronously loads media attachment for rich notification
    /// - Parameter completion: Completion handler with content including attachment
    func loadAttachmentAsync(completion: @escaping (UNNotificationContent) -> Void) {
        
        let service = AltcraftPushReceiver()
        
        guard let attachmentURL = service.extractMediaURL(content: content) else {
            completion(content)
            return
        }
        let (bestAttemptContent, tempDir) = service.prepareNotificationContent(content: content)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.downloadTask(with: attachmentURL) { tempURL, response, error in
            defer { semaphore.signal() }
            guard let tempURL = tempURL, error == nil else {
                errorEvent(#function, error: error ?? errorMediaDownload)
                return
            }
            service.addAttachment(to: bestAttemptContent, from: tempURL, in: tempDir)
        }.resume()
        
        _ = semaphore.wait(timeout: .now() + 25)
        completion(bestAttemptContent)
    }
}
