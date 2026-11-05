//
//  Header.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftPush
import SwiftUI

/// Rectangle with rounded bottom corners.
struct BottomRoundedRectangle: Shape {
    /// Draws the header shape path.
    ///
    /// - Parameter rect: Drawing bounds.
    /// - Returns: Shape path.
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 5
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

/// Builds the application header view.
func Header() -> some View {
    ZStack {
        BottomRoundedRectangle()
            .fill(Color.white)
            .frame(height: 100)
            .shadow(radius: 3)

        HStack {
            Image("altcraftclear")
                .resizable()
                .frame(width: 85, height: 18)
                .padding(.leading, 15)
                .offset(y: 15)
                //.offset(x: 05)
            Spacer()
        }
    }
}
