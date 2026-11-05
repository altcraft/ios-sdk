//
//  EditTextRow.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import SwiftUI

/// Labeled text input row.
struct EditTextRow: View {
    let name: String
    @Binding var text: String
    var hint: String?
    var startPadding: CGFloat = 15
    var endPadding: CGFloat = 15
    var ovalBoxHeight: CGFloat = 25
    var boxRadius: CGFloat = 30
    var whiteBoxSize: CGFloat = 20
    var whiteBoxPadding: CGFloat = 5
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 5) {
                HStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .stroke(Color.gray, lineWidth: 1.5)
                            .frame(
                                width: whiteBoxSize - whiteBoxPadding * 2,
                                height: whiteBoxSize - whiteBoxPadding * 2
                            )

                        Circle()
                            .fill(Color.black)
                            .frame(
                                width: whiteBoxSize - whiteBoxPadding * 2,
                                height: whiteBoxSize - whiteBoxPadding * 2
                            )
                            .shadow(radius: 5)
                    }
                    .frame(
                        width: whiteBoxSize,
                        height: whiteBoxSize
                    )

                    Text(name)
                        .foregroundColor(.black)
                        .font(.system(size: 8))
                        .fontWeight(.regular)
                        .fixedSize()
                }
                .padding(.leading, 5)
                .frame(
                    height: ovalBoxHeight,
                    alignment: .center
                )

                ZStack(alignment: .leading) {
                    if text.isEmpty, let hint, !hint.isEmpty {
                        Text(hint)
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                    }

                    TextField("", text: $text)
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .accessibilityIdentifierIfPresent(
                            accessibilityIdentifier
                        )
                }
                .frame(maxWidth: .infinity)
                .offset(y: 3)
            }

            Spacer()
                .frame(height: 4)

            Divider()
                .background(
                    Color.gray.opacity(0.5)
                )
                .padding(.vertical, 4)
        }
        .padding(
            .leading,
            startPadding
        )
        .padding(
            .trailing,
            endPadding
        )
    }
}
