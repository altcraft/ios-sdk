//
//  SubscribeStatusIndicator.swift
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

/// Module status indicator.
struct ModuleStatusIndicator: View {
    let status: Bool
    var size: CGFloat? = 15
    
    var body: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    gradient: status
                        ? Gradient(colors: [Color(hex: "#adf7bd"), Color(hex: "#33ff5f")])
                        : Gradient(colors: [Color(hex: "#ff6e7f"), Color(hex: "#DD2C00")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size)
    }
}

/// Subscription status indicator.
struct SubscribeStatusIndicator: View {
    var status: String = AppConstants.SubscriptionStatus.unsubscribed
    var size: CGFloat = 15
    var topPadding: CGFloat = 0
    
    var body: some View {
        let (startColor, endColor) = gradientColors(for: status)

        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [startColor, endColor]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: size, height: size)
            .padding(.top, topPadding)
    }

    /// Returns the gradient colors for the subscription status.
    ///
    /// - Parameter status: Subscription status.
    /// - Returns: Start and end gradient colors.
    private func gradientColors(for status: String) -> (Color, Color) {
        switch status {
        case AppConstants.SubscriptionStatus.subscribed:
            return (Color(hex: "#adf7bd"), Color(hex: "#33ff5f"))
        case AppConstants.SubscriptionStatus.suspended:
            return (Color(hex: "#FFD700"), Color(hex: "#FFD700"))
        case AppConstants.SubscriptionStatus.unsubscribed:
            return (Color(hex: "#ff6e7f"), Color(hex: "#ff6e7f"))
        default:
            return (Color(hex: "#ff6e7f"), Color(hex: "#ff6e7f"))
        }
    }
}
