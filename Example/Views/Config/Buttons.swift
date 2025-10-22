//
//  Buttons.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct AddButton: View {
    let action: () -> Void
    var buttonSize: CGFloat = 24
    var iconSize: CGFloat = 18
    var iconColor: Color = .black
    var iconBackgroundColor: Color = Color(red: 0.68, green: 0.97, blue: 0.74).opacity(0.4)

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

                PlusIcon(lineWidth: 10, lineHeight: 2.5, color: iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RemoveButton: View {
    let action: () -> Void
    var buttonSize: CGFloat = 24
    var iconSize: CGFloat = 18
    var iconBackgroundColor: Color = Color.black.opacity(0.1)

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

                XShapedIcon(lineWidth: 2.5, lineHeight: 10, firstColor: .black, secondColor: .black)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
