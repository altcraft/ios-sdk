//
//  InfoComponents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftProfile
import AltcraftTarget
import SwiftUI

/// Information row with token and date.
struct InfoItemView: View {
    var title: String
    var imageName: String
    var displayText: String
    var iconSize: CGFloat = 20

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .frame(width: 137, height: 135)
                .shadow(radius: 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 35, height: 35)

                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                    }

                    Text(title)
                        .font(.system(size: 11))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .frame(width: 75, alignment: .leading)
                }
                .padding(.top, 10)
                .padding(.leading, 10)

                Spacer()

                Text(displayText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)

                Spacer()
            }
            .frame(width: 137, height: 135)
        }
    }
}

// MARK: - createInfoItemView helper (legacy)

/// Builds an information row view.
///
/// - Parameters:
///   - index: Row index.
///   - token: Token string to display.
///   - date: Date string to display.
/// - Returns: Configured info row view.
func createInfoItemView(
    index: Int,
    token: String,
    date: String
) -> InfoItemView {
    let userName = configSubString(
        input: getConfigFromUserDefault()?.apiUrl
    )

    switch index {
    case 0:
        return InfoItemView(
            title: "device token:",
            imageName: "ic_apns_logo",
            displayText: token
        )

    case 1:
        return InfoItemView(
            title: "platform:",
            imageName: "ic_os",
            displayText: "iOS",
            iconSize: 28
        )

    case 2:
        return InfoItemView(
            title: "update time:",
            imageName: "ic_time",
            displayText: date
        )

    case 3:
        return InfoItemView(
            title: "user:",
            imageName: "ic_setting",
            displayText: userName
        )

    default:
        return InfoItemView(
            title: "",
            imageName: "",
            displayText: ""
        )
    }
}

// MARK: - ModuleCard

/// SDK module info card.
struct ModuleCard: View {
    let moduleName: String?
    let imageName: String
    let status: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white)
                    .frame(width: 90, height: 63)
                    .shadow(radius: 2)

                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 37, height: 37)

                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text(moduleName ?? "")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .offset(y: 3)

                        Spacer()
                            .frame(height: 20)

                        HStack(spacing: 10) {
                            Text(status ? "on" : "off")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.black)

                            ModuleStatusIndicator(
                                status: status,
                                size: 7
                            )
                        }
                        .offset(y: -7)
                    }
                }
                .padding(.top, 7)
                .padding(.leading, 3)
            }
            .frame(width: 90, height: 66)
        }
        .buttonStyle(.plain)
    }
}

/// Status grid layout.
struct InfoStatusGrid: View {

    @ObservedObject private var inAppStatusManager =
        GlobalInAppStatusManager.shared

    @ObservedObject private var pushStatusManager =
        GlobalPushStatusManager.shared

    @ObservedObject private var authStatusManager =
        GlobalAuthStatusManager.shared

    let paddingHorizontal: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat

    init(
        paddingHorizontal: CGFloat = 5,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        self.paddingHorizontal = paddingHorizontal
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {

                InfoStatusCard(
                    onClick: {
                        inAppStatusManager.toggle()
                    },
                    content: {
                        InfoInAppStatus(
                            status: inAppStatusManager.isSubscribed
                        )
                    },
                    accessibilityIdentifier: "home_inapp_subscription_button"
                )

                InfoStatusCard(
                    onClick: {
                        pushStatusManager.toggle()
                    }
                ) {
                    InfoPushStatus(
                        status: pushStatusManager.isSubscribed
                    )
                }

                InfoStatusCard(
                    onClick: {
                        authStatusManager.toggle()
                    },
                    content: {
                        InfoAuthStatus(
                            status: authStatusManager.isAuthenticated
                        )
                    },
                    accessibilityIdentifier: "home_auth_button"
                )

                InfoStatusCard(
                    onClick: {
                        openUrl(
                            "https://github.com/altcraft/ios-sdk"
                        )
                    }
                ) {
                    Image("ic_github")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                InfoStatusCard(alpha: 0) {
                    Color.clear
                }
                .allowsHitTesting(false)

                InfoStatusCard(alpha: 0) {
                    Color.clear
                }
                .allowsHitTesting(false)

                InfoStatusCard(alpha: 0) {
                    Color.clear
                }
                .allowsHitTesting(false)

                InfoStatusCard(
                    onClick: {
                        openUrl(
                            "https://guides.altcraft.com/developer-guide/sdk/mobile/ios/"
                        )
                    }
                ) {
                    Image("altlogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(
            .horizontal,
            paddingHorizontal
        )
        .padding(.top, 3)
        .offset(
            x: offsetX,
            y: offsetY
        )
    }

    /// Opens the URL in the system browser.
    ///
    /// - Parameter urlString: URL to open.
    private func openUrl(
        _ urlString: String
    ) {
        guard let url = URL(
            string: urlString
        ) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

// MARK: - InfoStatusCard

/// Status card container.
struct InfoStatusCard<Content: View>: View {
    var alpha: Double
    var onClick: (() -> Void)?
    let content: () -> Content
    var accessibilityIdentifier: String?

    init(
        alpha: Double = 1.0,
        onClick: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content,
        accessibilityIdentifier: String? = nil
    ) {
        self.alpha = alpha
        self.onClick = onClick
        self.content = content
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        ZStack {
            content()
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 1)
        .padding(3)
        .opacity(alpha)
        .accessibilityIdentifierIfPresent(
            accessibilityIdentifier
        )
        .onTapGesture {
            onClick?()
        }
    }
}

// MARK: - OnBadge

/// Status badge.
struct InfoOnBadge: View {
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(
                    width: size + 2,
                    height: size + 2
                )

            Circle()
                .fill(Color.black)
                .frame(
                    width: size,
                    height: size
                )

            Image("ic_check")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(.white)
                .frame(
                    width: size * 0.55,
                    height: size * 0.55
                )
        }
    }
}

// MARK: - PushStatusProcess views

/// Push status indicator.
struct InfoPushStatus: View {
    var status: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("ic_bell_3")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .opacity(0.7)

            if status {
                InfoOnBadge(size: 11)
                    .offset(x: 0, y: -2)
            }
        }
        .frame(width: 22, height: 22)
    }
}

/// In-app status indicator.
struct InfoInAppStatus: View {
    var status: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("ic_example")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .opacity(0.5)

            if status {
                InfoOnBadge(size: 11)
                    .offset(x: 0, y: -2)
            }
        }
        .frame(width: 24, height: 24)
    }
}

/// Authentication status indicator.
struct InfoAuthStatus: View {
    var status: Bool

    var body: some View {
        ZStack {
            if status {
                Circle()
                    .fill(
                        Color(hex: 0xADF7BD)
                            .opacity(0.5)
                    )
                    .frame(
                        width: 15,
                        height: 15
                    )
            }

            Image("ic_fingerprint")
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
        }
    }
}

// MARK: - RoundedCorner shape

/// Shape rounding selected corners.
struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    /// Draws the rounded shape path.
    ///
    /// - Parameter rect: Drawing bounds.
    /// - Returns: Shape path.
    func path(
        in rect: CGRect
    ) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: radius,
                height: radius
            )
        )

        return Path(path.cgPath)
    }
}

// MARK: - Color hex helper (UInt version, kept for compatibility)

extension Color {
    init(hex uint: UInt) {
        self.init(
            red: Double(
                (uint >> 16) & 0xFF
            ) / 255.0,
            green: Double(
                (uint >> 8) & 0xFF
            ) / 255.0,
            blue: Double(
                uint & 0xFF
            ) / 255.0
        )
    }
}
