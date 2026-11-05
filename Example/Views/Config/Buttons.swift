//
//  Buttons.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import SwiftUI

/// Add button for key-value editors.
struct AddButton: View {
    let action: () -> Void
    var buttonSize: CGFloat = 24
    var iconSize: CGFloat = 18
    var iconColor: Color = .black
    var iconBackgroundColor: Color = Color(red: 0.68, green: 0.97, blue: 0.74).opacity(0.4)
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(radius: 3)

                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: iconSize, height: iconSize)

                PlusIcon(
                    lineWidth: 10,
                    lineHeight: 2.5,
                    color: iconColor
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifierIfPresent(accessibilityIdentifier)
    }
}

/// Remove button for key-value editors.
struct RemoveButton: View {
    let action: () -> Void
    var buttonSize: CGFloat = 24
    var iconSize: CGFloat = 18
    var iconBackgroundColor: Color = Color.black.opacity(0.1)
    var accessibilityIdentifier: String? = nil

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .shadow(radius: 3)

                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: iconSize, height: iconSize)

                XShapedIcon(
                    lineWidth: 2.5,
                    lineHeight: 10,
                    firstColor: .black,
                    secondColor: .black
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifierIfPresent(accessibilityIdentifier)
    }
}

extension View {
    /// Attaches an accessibility identifier when the value is non-empty.
    ///
    /// - Parameter identifier: Identifier to attach, or `nil`.
    /// - Returns: Modified view.
    @ViewBuilder
    func accessibilityIdentifierIfPresent(
        _ identifier: String?
    ) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
