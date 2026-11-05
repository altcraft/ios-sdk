//
//  Switch.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import SwiftUI

/// Custom toggle switch style.
struct CustomSwitchStyle: ToggleStyle {
    /// Builds the custom toggle switch body.
    ///
    /// - Parameter configuration: Toggle configuration.
    /// - Returns: Configured switch view.
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 50, height: 25)
                .shadow(radius: 2)
                .overlay(
                    Circle()
                        .fill(configuration.isOn ? Color(red: 0x5a/255, green: 0xe0/255, blue: 0xea/255) : Color.black)
                        .frame(width: 15, height: 15)
                        .offset(x: configuration.isOn ? 15 : -15)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
        .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
    }
}
