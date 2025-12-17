//
//  PushActionHandler.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit

/// Handles actions related to tapping a push notification or its buttons.
@available(iOSApplicationExtension, unavailable)
final class PushAction {
    
    public static let shared = PushAction()

    /// Entry point: handles a push notification tap or button press.
    ///
    /// - Parameters:
    ///   - userInfo: The original push notification payload (`userInfo`).
    ///   - identifier: The action identifier received from `UNUserNotificationCenter`.
    func pushClickAction(userInfo: [String: Any], Identifier: String) {
        guard let buttonsAsString = userInfo[Constants.UserInfoKeys.buttons] as? String,
              let buttonsData = buttonsAsString.data(using: .utf8) else {
            errorEvent(#function, error: errorButtonsKeyMissing)
            return
        }

        let buttons: [[String: String]]
        do {
            buttons = try JSONDecoder().decode([[String: String]].self, from: buttonsData)
        } catch {
            errorEvent(#function, error: error)
            return
        }

        handleButtonAction(identifier: Identifier, buttons: buttons, userInfo: userInfo)
    }

    /// Handles a push notification tap or button press and opens the linked URL if available.
    ///
    /// For `Constants.ButtonIdentifier.defaultNotificationAction` (tap on notification body),
    /// tries to open `clickUrl`. If no link is provided, does nothing — the system already opens the app.
    ///
    /// - Parameters:
    ///   - identifier: Action identifier.
    ///   - buttons: Button metadata (may include links).
    ///   - userInfo: Original notification payload.
    private func handleButtonAction(
        identifier: String,
        buttons: [[String: String]],
        userInfo: [String: Any]
    ) {
        switch identifier {
        case Constants.ButtonIdentifier.defaultNotificationAction: openURL(
            from: userInfo[Constants.UserInfoKeys.clickUrl] as? String
        )
            
        case Constants.ButtonIdentifier.buttonOne,
            Constants.ButtonIdentifier.buttonTwo,
            Constants.ButtonIdentifier.buttonThree:
            
            guard let index = buttonIndex(for: identifier) else {
                errorEvent(
                    #function,
                    error: invalidButtonIdentifier,
                    value: [Constants.MapKeys.identifier: identifier]
                )
                return
            }
            
            guard buttons.indices.contains(index) else {
                errorEvent(
                    #function,
                    error: invalidButtonIdentifier,
                    value: [
                        Constants.MapKeys.identifier: identifier,
                        Constants.MapKeys.index: index
                    ]
                )
                return
            }
            
            let buttonData = buttons[index]
            let link = buttonData[Constants.MapKeys.link]
            openURL(from: link)
            
        default:
            errorEvent(
                #function,
                error: unknownButtonIdentifier,
                value: [Constants.MapKeys.identifier: identifier]
            )
        }
    }

    /// Returns the index corresponding to a button identifier.
    ///
    /// - Parameter identifier: A string representing the button identifier.
    /// - Returns: An optional integer representing the index of the button.
    ///  Returns `nil` if the identifier is not recognized.
    private func buttonIndex(for identifier: String) -> Int? {
        switch identifier {
        case Constants.ButtonIdentifier.buttonOne: return 0
        case Constants.ButtonIdentifier.buttonTwo: return 1
        case Constants.ButtonIdentifier.buttonThree: return 2
        default: return nil
        }
    }

    /// Opens a URL if it is valid and can be opened.
    private func openURL(from link: String?) {
        guard let link = link,
              let url = URL(string: link),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
