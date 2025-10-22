//
//  PushAction.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import UIKit

/// Handles actions related to clicking on push notifications.
public func pushClickAction(userInfo: [String: Any], identifier: String) {
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
    handleButtonAction(identifier: identifier, buttons: buttons, userInfo: userInfo)
}

/// Determines which push notification button was pressed based on the action identifier,
/// and handles opening the appropriate link or deep link.
///
/// If the `identifier` equals `"com.apple.UNNotificationDefaultActionIdentifier"`,
/// it means the user tapped the notification body. In that case, a default link or deep link
/// will be opened if available. If no links are defined, the app will navigate to the default view.
///
/// - Parameters:
///   - identifier: A string representing the identifier of the triggered action.
///   - buttons: An array of dictionaries containing metadata about the buttons.
///   - userInfo: A dictionary containing the original push notification payload.
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
/// - Returns: An optional integer representing the index of the button. Returns `nil` if the identifier is not recognized.
private func buttonIndex(for identifier: String) -> Int? {
    switch identifier {
    case Constants.ButtonIdentifier.buttonOne: return 0
    case Constants.ButtonIdentifier.buttonTwo: return 1
    case Constants.ButtonIdentifier.buttonThree: return 2
    default: return nil
    }
}

/// Opens a URL if it is valid and can be opened.
///
/// - Parameter link: An optional string representing the URL to be opened.
///
/// This method checks if the URL is valid and can be opened. If so, it opens the URL using the `UIApplication` shared instance.
func openURL(from link: String?) {
    guard let link = link, let url = URL(string: link), UIApplication.shared.canOpenURL(url) else {
        return
    }
    UIApplication.shared.open(url)
}
