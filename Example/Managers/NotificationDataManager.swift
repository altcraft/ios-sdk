//
//  NotificationDataManager.swift
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
import SwiftUI

/// Parsed notification content for the demo screen.
struct NotificationPayload: Codable {
    let title: String
    let body: String
    let image: String?
    let buttons: [String]
}

/// Holds and displays the last notification payload.
@MainActor
class NotificationDataManager: ObservableObject {
    @Published var title: String = "Altcraft"
    @Published var body: String = "Welcome to the Altcraft Notification Builder!"
    @Published var image: UIImage? = nil
    @Published var buttons: [String] = []
    @Published var imageUrl: String? = nil

    private let userDefaultsKey = "NotificationPayloadData"
    private let imageUrlKey = "NotificationImageURL"

    init() {
        loadFromUserDefaults()
        loadImageFromStoredUrl()
    }

    /// Replaces the stored notification payload.
    ///
    /// - Parameter data: Parsed notification payload.
    func update(from data: NotificationPayload) {
        self.title = data.title
        self.body = data.body
        self.buttons = data.buttons
        self.imageUrl = data.image
        saveToUserDefaults()

        loadImage(from: data.image) { [weak self] in self?.image = $0 }
    }

    /// Loads the stored notification payload from UserDefaults.
    func loadFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let payload = try? JSONDecoder().decode(NotificationPayload.self, from: data) {
            self.title = payload.title
            self.body = payload.body
            self.buttons = payload.buttons
            self.imageUrl = payload.image
        }

        loadImageFromStoredUrl()
    }

    /// Clears the stored notification payload and image.
    func clearData() {
        title = ""
        body = ""
        image = nil
        imageUrl = nil
        buttons = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: imageUrlKey)
    }

    /// Stores the notification image URL and starts loading.
    ///
    /// - Parameter url: Image URL, or `nil` to clear.
    func setImageUrl(_ url: String?) {
        self.imageUrl = url
        if let url = url {
            UserDefaults.standard.set(url, forKey: imageUrlKey)
        } else {
            UserDefaults.standard.removeObject(forKey: imageUrlKey)
        }

        loadImage(from: url) { [weak self] in self?.image = $0 }
    }

    /// Loads the image for the stored URL.
    private func loadImageFromStoredUrl() {
        let url = UserDefaults.standard.string(forKey: imageUrlKey)
        self.imageUrl = url
        loadImage(from: url) { [weak self] in self?.image = $0 }
    }

     /// Persists the notification payload to UserDefaults.
     func saveToUserDefaults() {
        let payload = NotificationPayload(
            title: title,
            body: body,
            image: imageUrl,
            buttons: buttons
        )

        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// Downloads the image from the URL asynchronously.
    ///
    /// - Parameters:
    ///   - urlString: Image URL, or `nil`.
    ///   - completion: Called with the downloaded image, or `nil`.
    private func loadImage(from urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let image = UIImage(data: data)
                completion(image)
            } catch {
                completion(nil)
            }
        }
    }
}

/// Shared `NotificationDataManager` singleton.
@MainActor
class GlobalNotificationDataManager {static let shared = NotificationDataManager()}

import UserNotifications

@MainActor
extension NotificationDataManager {
    
    /// Action buttons configuration key.
    static let buttons = "_buttons"
    /// Rich media attachment key.
    static let media = "_media"

    /// Builds a local push payload and runs it through the AltcraftNSE
    /// processing flow.
    func sendPush() {
        let content = UNMutableNotificationContent()
        content.title = self.title
        content.body = self.body
        content.sound = .default
        content.categoryIdentifier = "Altcraft"

        let buttonsArray = buttons.map { ["label": $0] }

        // Use the same key AltcraftNSE/AltcraftPushReceiver expects: "_ac_push"
        var userInfo: [String: Any] = [
            "_ac_push": "Altcraft",
            NotificationDataManager.buttons: jsonString(from: buttonsArray)
        ]

        if let imageUrl = self.imageUrl {
            userInfo[NotificationDataManager.media] = imageUrl
        }

        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        // Handle via AltcraftNSE facade (Notification Service Extension flow)
        AltcraftNSE.handleNotificationRequest(request: request) { modifiedContent in
            let finalRequest = UNNotificationRequest(
                identifier: request.identifier,
                content: modifiedContent,
                trigger: request.trigger
            )
            sendFinalNotification(from: finalRequest)
        }

        // Schedules the final (possibly modified) notification
        /// Schedules the final (possibly enriched) notification for delivery.
        ///
        /// - Parameter request: Notification request to schedule.
        func sendFinalNotification(from request: UNNotificationRequest) {
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule local push: \(error.localizedDescription)")
                }
            }
        }
    }
    /// Serializes the object to a JSON string.
    ///
    /// - Parameter object: JSON-serializable object.
    /// - Returns: JSON string, or `nil` on failure.
    private func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

