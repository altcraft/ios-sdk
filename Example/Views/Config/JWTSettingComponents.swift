//
//  JWTSettingComponents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import SwiftUI

/// JWT values editing screen.
struct JWTSettingView: View {
    @StateObject private var manager = JWTSettingManager()
    @State private var editingAnonJWT: String = ""
    @State private var editingRegJWT: String = ""

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                HStack {
                    Text("JWT setting:")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 20) {
                        RemoveButton(
                            action: {
                                manager.clearJWTs()
                                editingAnonJWT = ""
                                editingRegJWT = ""
                            },
                            accessibilityIdentifier: "jwt_clear_button"
                        )

                        AddButton(
                            action: {
                                manager.anonJWT = editingAnonJWT.isEmpty
                                    ? manager.anonJWT
                                    : editingAnonJWT

                                manager.regJWT = editingRegJWT.isEmpty
                                    ? manager.regJWT
                                    : editingRegJWT

                                manager.saveJWTs()

                                editingAnonJWT = ""
                                editingRegJWT = ""
                            },
                            accessibilityIdentifier: "jwt_save_button"
                        )
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 10)

                GradientShadowLine(
                    colors: [
                        Color(
                            red: 0.55,
                            green: 0.75,
                            blue: 0.99,
                            opacity: 0.4
                        ),
                        Color.black.opacity(0.1),
                        Color(
                            red: 173 / 255,
                            green: 247 / 255,
                            blue: 189 / 255
                        ).opacity(0.4)
                    ],
                    height: 3,
                    horizontalPadding: 15
                )
            }
            .background(Color.white)

            EditTextRow(
                name: "Anon.JWT",
                text: $editingAnonJWT,
                hint: manager.anonJWT.isEmpty ? "" : manager.anonJWT,
                accessibilityIdentifier: "jwt_anon_input"
            )

            EditTextRow(
                name: "Reg.JWT",
                text: $editingRegJWT,
                hint: manager.regJWT.isEmpty ? "" : manager.regJWT,
                accessibilityIdentifier: "jwt_reg_input"
            )

            Spacer()
        }
    }
}
