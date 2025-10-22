//
//  MenuView.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI
import Altcraft


struct NavigatorView: View {
    @Binding var mode: Int

    var body: some View {
        ZStack {
            Color.white
                .frame(height: 60)

            HStack(spacing: 0) {
                menuButton(image: "home_icon_black", text: "Home", modeValue: 1)
                menuButton(image: "message_icon_black2", text: "Example", modeValue: 2)
                menuButton(image: "log_icon_black3", text: "Logs", modeValue: 3)
                menuButton(image: "setting_icon_black", text: "Config", modeValue: 4)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    @ViewBuilder
    private func menuButton(image: String, text: String, modeValue: Int) -> some View {
        Button(action: { mode = modeValue }) {
            VStack {
                Image(image)
                    .resizable()
                    .frame(width: 25, height: 25)
                Text(text)
                    .font(.system(size: 10))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
