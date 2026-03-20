//
//  PushActionHandler.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit

/// Handles user interaction with a push notification or its action buttons.
@available(iOSApplicationExtension, unavailable)
actor PushAction {

    public static let shared = PushAction()

    /// Handles a notification tap or button action.
    ///
    /// - Parameters:
    ///   - buttonsJSON: JSON string with button metadata from push payload.
    ///   - clickURL: URL to open for a default notification tap.
    ///   - identifier: Action identifier received from `UNUserNotificationCenter`.
    func pushClickAction(
        buttonsJSON: String?,
        clickURL: String?,
        identifier: String
    ) {
        guard let buttonsJSON,
              let buttonsData = buttonsJSON.data(using: .utf8) else {
            errorEvent(#function, error: errorButtonsKeyMissing)
            return
        }

        let buttons: [[String: String]]
        do {
            buttons = try JSONDecoder().decode(
                [[String: String]].self, from: buttonsData
            )
        } catch {
            errorEvent(#function, error: error)
            return
        }

        handleButtonAction(
            identifier: identifier,
            buttons: buttons,
            clickURL: clickURL
        )
    }

    /// Resolves the selected notification action and opens the corresponding URL if available.
    ///
    /// For the default notification tap, uses `clickURL`.
    /// For action buttons, uses the button link from decoded payload metadata.
    ///
    /// - Parameters:
    ///   - identifier: Action identifier.
    ///   - buttons: Decoded button metadata.
    ///   - clickURL: URL for the default notification tap.
    private func handleButtonAction(
        identifier: String,
        buttons: [[String: String]],
        clickURL: String?
    ) {
        switch identifier {
        case Constants.ButtonIdentifier.defaultNotificationAction:
            openURL(from: clickURL)

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

    /// Returns the button index for a given action identifier.
    ///
    /// - Parameter identifier: Notification action identifier.
    /// - Returns: Button index if the identifier is recognized, otherwise `nil`.
    private func buttonIndex(for identifier: String) -> Int? {
        switch identifier {
        case Constants.ButtonIdentifier.buttonOne: return 0
        case Constants.ButtonIdentifier.buttonTwo: return 1
        case Constants.ButtonIdentifier.buttonThree: return 2
        default: return nil
        }
    }

    /// Opens a URL if it is valid and supported by the system.
    ///
    /// - Parameter link: URL string to open.
    private func openURL(from link: String?) {
        guard let link = link, let url = URL(string: link) else {
            return
        }

        DispatchQueue.main.async {
            guard UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }
    }
}
