//
//  NavigatorView.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftTarget
import SwiftUI

/// Navigation menu view.
struct NavigatorView: View {
    @Binding var mode: Int

    var body: some View {
        ZStack {
            Color.white
                .frame(height: 60)

            HStack(spacing: 0) {
                menuButton(image: "ic_home", text: "Home", modeValue: 1)
                menuButton(image: "ic_example", text: "Example", modeValue: 2)
                menuButton(image: "ic_log", text: "Logs", modeValue: 3)
                menuButton(image: "ic_in_app", text: "InApp", modeValue: 4)
                menuButton(image: "ic_setting_black", text: "Config", modeValue: 5)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    /// Builds a menu navigation button.
    ///
    /// - Parameters:
    ///   - image: Button icon name.
    ///   - text: Button title.
    ///   - modeValue: Target screen mode.
    /// - Returns: Configured menu button.
    @ViewBuilder
    private func menuButton(image: String, text: String, modeValue: Int) -> some View {
        Button(action: { mode = modeValue }) {
            VStack {
                Image(image)
                    .resizable()
                    .frame(width: 22.5, height: 22.5)
                Text(text)
                    .font(.system(size: 10))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
