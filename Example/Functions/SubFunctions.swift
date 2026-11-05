//
//  SubFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftPush
import AltcraftTarget
import SwiftUI

extension View {
    /// Adds a border overlay around the given view content.
    ///
    /// - Parameters:
    ///   - content: View content to decorate.
    ///   - width: Border width.
    ///   - cornerRadius: Corner radius of the border.
    public func addBorder<S>(_ content: S, width: CGFloat = 1, cornerRadius: CGFloat) -> some View where S : ShapeStyle {
        let roundedRect = RoundedRectangle(cornerRadius: cornerRadius)
        return clipShape(roundedRect)
             .overlay(roundedRect.strokeBorder(content, lineWidth: width))
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
/// Scales the image to fit the target size.
///
/// - Parameters:
///   - image: Source image.
///   - targetSize: Maximum resulting size.
/// - Returns: Scaled image.
func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    let size = image.size
    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    var newSize: CGSize
    if widthRatio > heightRatio {
        newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
        newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
    }
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resizedImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
    }
    return resizedImage
}

/// Returns the token suffix used for UI display.
///
/// - Parameter input: Full token string.
/// - Returns: Last characters of the token.
func getTokenSubString(of input: String) -> String {
    return input.count > 10 ? String(input.suffix(10)) : input
}

/// Returns a shortened configuration string for UI display.
///
/// - Parameter input: Full configuration string.
/// - Returns: Truncated string, or an empty string.
func configSubString(input: String?) -> String {
    guard let input = input else { return ""}
    guard input.count > 12 else {
        return input.isEmpty ? "" : input
    }
    let startIndex = input.index(input.startIndex, offsetBy: 12)
    if let endIndex = input[startIndex...].firstIndex(of: ".") {
        return String(input[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
    }
    return ""
}
