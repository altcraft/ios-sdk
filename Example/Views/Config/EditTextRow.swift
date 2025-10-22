//
//  EditTextRow.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct EditTextRow: View {
    let name: String
    @Binding var text: String
    let hint: String?
    var startPadding: CGFloat = 15
    var endPadding: CGFloat = 15
    var font: Font = .system(size: 12)
    var textColor: Color = .black
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .stroke(Color.gray, lineWidth: 1.5)
                        .background(
                            Circle()
                                .fill(Color.black)
                                .shadow(color: .gray.opacity(0.4), radius: 5)
                        )
                        .frame(width: 10, height: 10)

                    Text(name)
                        .font(.system(size: 8))
                }
                .padding(.leading, startPadding)

                TextField("", text: $text, prompt: Text(hint ?? "").foregroundColor(.gray))
                    .font(font)
                    .foregroundColor(textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                    .focused($isFocused)
            }
            .padding(.trailing, endPadding)

            Spacer().frame(height: 4)

            Divider()
                .background(Color.gray.opacity(0.5))
                .padding(.vertical, 4)
                .padding(.horizontal, 15)
        }
    }
}
