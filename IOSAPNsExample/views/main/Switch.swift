//
//  Switch.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct CustomSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            RoundedRectangle(cornerRadius: 20)
                .fill(configuration.isOn ? Color.white : Color.white)
                .frame(width: 50, height: 25)
                .shadow(radius: 2)
                .overlay(
                    Circle()
                        .fill(configuration.isOn ? Color(hex: "5ae0ea") : Color.black)
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
