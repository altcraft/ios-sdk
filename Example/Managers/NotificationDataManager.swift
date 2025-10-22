//
//  NotificationDataManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct NotificationPayload: Codable {
    let title: String
    let body: String
    let image: String?
    let buttons: [String]
}

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

    func update(from data: NotificationPayload) {
        self.title = data.title
        self.body = data.body
        self.buttons = data.buttons
        self.imageUrl = data.image
        saveToUserDefaults()

        loadImage(from: data.image) { [weak self] in self?.image = $0 }
    }

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

    func clearData() {
        title = ""
        body = ""
        image = nil
        imageUrl = nil
        buttons = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: imageUrlKey)
    }

    func setImageUrl(_ url: String?) {
        self.imageUrl = url
        if let url = url {
            UserDefaults.standard.set(url, forKey: imageUrlKey)
        } else {
            UserDefaults.standard.removeObject(forKey: imageUrlKey)
        }

        loadImage(from: url) { [weak self] in self?.image = $0 }
    }

    private func loadImageFromStoredUrl() {
        let url = UserDefaults.standard.string(forKey: imageUrlKey)
        self.imageUrl = url
        loadImage(from: url) { [weak self] in self?.image = $0 }
    }

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

@MainActor
class GlobalNotificationDataManager {static let shared = NotificationDataManager()}


import UserNotifications
import Altcraft


@MainActor
extension NotificationDataManager {
    
    /// Action buttons configuration key.
    static let buttons = "_buttons"
    /// Rich media attachment key.
    static let media = "_media"

    func sendPush() {
        let content = UNMutableNotificationContent()
        content.title = self.title
        content.body = self.body
        content.sound = .default
        content.categoryIdentifier = "Altcraft"

        let buttonsArray = buttons.map { ["label": $0] }

        var userInfo: [String: Any] = [
            "_as_push": "Altcraft",
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

        // Обработка пуша
        let service = AltcraftPushReceiver()
        service.didReceive(request) { modifiedContent in
            let finalRequest = UNNotificationRequest(
                identifier: request.identifier,
                content: modifiedContent,
                trigger: request.trigger
            )
            sendFinalNotification(from: finalRequest)
        }
         func sendFinalNotification(from request: UNNotificationRequest) {
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule local push: \(error.localizedDescription)")
                }
            }
        }
    }

    private func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}


