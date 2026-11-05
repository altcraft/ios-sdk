//
//  ActionComponents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget
import SwiftUI

/// Generic action button.
struct ActionButton: View {
    var label: String
    var onClick: () -> Void
    var customIcon: (() -> AnyView)? = nil
    var accessibilityIdentifier: String? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(radius: 5)

                Circle()
                    .fill(Color.black)
                    .frame(width: 50, height: 50)
                    .shadow(radius: 3)

                if let customIcon = customIcon {
                    customIcon()
                }
            }
            .contentShape(Circle())
            .accessibilityIdentifierIfPresent(accessibilityIdentifier)
            .onTapGesture {
                onClick()
            }
            .frame(width: 90)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(width: 70)
        }
    }
}

//Subscribe Icon
/// Plus glyph.
struct PlusIcon: View {
    var lineWidth: CGFloat
    var lineHeight: CGFloat
    var color: Color = Color(hex: "#33FF5F")

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(width: lineWidth, height: lineHeight)

            RoundedRectangle(cornerRadius: 5)
                .fill(color)
                .frame(width: lineHeight, height: lineWidth)
        }
    }
}

//Profile Icon
/// Common glyph.
struct CommonIcon: View {
    var rotationDegrees: Double = 0
    var circleSize: CGFloat = 7
    var circleColor: Color = .white
    var checkMarkColor: Color = Color(hex: "#8DBFFC")

    var body: some View {
        ZStack {
            Circle()
                .fill(circleColor)
                .frame(width: circleSize, height: circleSize)
                .offset(y: -5)

            CheckMarkIcon(
                strokeWidth: 3,
                strokeColor: checkMarkColor
            )
        }
        .frame(width: 17, height: 17)
        .rotationEffect(.degrees(rotationDegrees))
    }
}

/// Checkmark glyph.
struct CheckMarkIcon: View {
    var strokeWidth: CGFloat = 3
    var strokeColor: Color = Color(hex: "#8DBFFC")

    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height

            let bottom = CGPoint(x: w / 2, y: h * 0.9)
            let left = CGPoint(x: w * 0.15, y: h * 0.65)
            let right = CGPoint(x: w * 0.85, y: h * 0.65)

            Path { path in
                path.move(to: left)
                path.addLine(to: bottom)
                path.move(to: right)
                path.addLine(to: bottom)
            }
            .stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: strokeWidth,
                    lineCap: .round
                )
            )
        }
    }
}

//Update Icon
/// U-shaped glyph.
struct UShapedIcon: View {
    var strokeWidth: CGFloat = 2.5
    var width: CGFloat = 15
    var height: CGFloat = 7.5
    var topArcColor: Color = Color(hex: "#8DBFFC")
    var bottomArcColor: Color = .white

    var body: some View {
        VStack {
            ArcShapeUp()
                .stroke(topArcColor, lineWidth: strokeWidth)
                .frame(width: width, height: height)
                .offset(y: 4)

            ArcShapeDown()
                .stroke(bottomArcColor, lineWidth: strokeWidth)
                .frame(width: width, height: height)
                .offset(y: -11.3)
        }
    }
}

//clear icon 1
/// Upper arc shape.
struct ArcShapeUp: Shape {
    /// Draws the shape path.
    ///
    /// - Parameter rect: Drawing bounds.
    /// - Returns: Shape path.
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )

        return path
    }
}

//clear icon 2
/// Lower arc shape.
struct ArcShapeDown: Shape {
    /// Draws the lower arc shape path.
    ///
    /// - Parameter rect: Drawing bounds.
    /// - Returns: Shape path.
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.maxY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )

        return path
    }
}

//Clear Icon
/// X-shaped glyph.
struct XShapedIcon: View {
    var lineWidth: CGFloat
    var lineHeight: CGFloat
    var firstColor: Color = Color(hex: "#8DBFFC")
    var secondColor: Color = .white

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(firstColor)
                .frame(width: lineWidth, height: lineHeight)
                .rotationEffect(.degrees(-45))

            RoundedRectangle(cornerRadius: 5)
                .fill(secondColor)
                .frame(width: lineWidth, height: lineHeight)
                .rotationEffect(.degrees(45))
        }
    }
}

//SubBox
/// Subscription section box.
struct SubBoxView: View {
    var subscribe: Bool
    var rounded: CGFloat = 10

    var body: some View {
        VStack {
            GeometryReader { geometry in
                let horizontalPadding: CGFloat = 20
                let loginWidth: CGFloat = 88.5
                let availableWidth = geometry.size.width - horizontalPadding - loginWidth
                let unit = availableWidth / 6

                HStack(spacing: 0) {
                    VerticalSubLabel(
                        text: "push",
                        backgroundColor: Color(hex: "#33FF5F").opacity(0.1)
                    )
                    .frame(width: unit)
                    .padding(.trailing, 2.5)

                    VStack(spacing: 0) {
                        SubActionBox(
                            label: "Subscribe",
                            backgroundColor: Color(hex: "#33FF5F").opacity(0.1),
                            icon: AnyView(
                                PlusIcon(
                                    lineWidth: 10,
                                    lineHeight: 2,
                                    color: Color.black
                                )
                            ),
                            iconSize: 20,
                            textSize: 8,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                pushSubscribe()
                            }
                        )

                        SubActionBox(
                            label: "Unsubscribe",
                            backgroundColor: Color.black.opacity(0.1),
                            icon: AnyView(
                                XShapedIcon(
                                    lineWidth: 10,
                                    lineHeight: 2,
                                    firstColor: Color.black,
                                    secondColor: Color.black
                                )
                            ),
                            iconSize: 20,
                            textSize: 8,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                pushUnsubscribe()
                            }
                        )
                    }
                    .frame(width: unit * 2)

                    VerticalSubLabel(
                        text: "inapp",
                        backgroundColor: Color(hex: "#8DBFFC").opacity(0.1)
                    )
                    .frame(width: unit)
                    .padding(.horizontal, 2.5)

                    VStack(spacing: 0) {
                        SubActionBox(
                            label: "Subscribe",
                            backgroundColor: Color(hex: "#8DBFFC").opacity(0.1),
                            icon: AnyView(
                                PlusIcon(
                                    lineWidth: 10,
                                    lineHeight: 2,
                                    color: Color.black
                                )
                            ),
                            iconSize: 20,
                            textSize: 8,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                AltcraftSDK.inApp.subscription.subscribe()
                            }
                        )

                        SubActionBox(
                            label: "Unsubscribe",
                            backgroundColor: Color.black.opacity(0.1),
                            icon: AnyView(
                                XShapedIcon(
                                    lineWidth: 10,
                                    lineHeight: 2,
                                    firstColor: Color.black,
                                    secondColor: Color.black
                                )
                            ),
                            iconSize: 20,
                            textSize: 8,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                AltcraftSDK.inApp.subscription.unsubscribe()
                            }
                        )
                    }
                    .frame(width: unit * 2)

                    VStack(spacing: 0) {
                        SubActionBox(
                            label: "Log In",
                            backgroundColor: Color.black.opacity(0.7),
                            icon: AnyView(
                                CommonIcon(
                                    rotationDegrees: -90,
                                    circleColor: Color.clear,
                                    checkMarkColor: Color.white
                                )
                            ),
                            iconSize: 23,
                            textSize: 10,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                logIn()
                            }
                        )

                        SubActionBox(
                            label: "Log Out",
                            backgroundColor: Color.black.opacity(0.7),
                            icon: AnyView(
                                CommonIcon(
                                    rotationDegrees: 90,
                                    circleColor: Color.clear,
                                    checkMarkColor: Color.white
                                )
                            ),
                            iconSize: 23,
                            textSize: 10,
                            onClick: {
                                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                                logOut()
                            }
                        )
                    }
                    .frame(width: loginWidth)
                }
                .padding(.horizontal, 10)
            }
            .frame(height: 130)

            Spacer().frame(height: 15)

            SectionInfoView {
                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
            }
        }
    }
}

/// Vertical section label.
struct VerticalSubLabel: View {
    var text: String
    var backgroundColor: Color

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(text), id: \.self) { character in
                Text(String(character))
                    .font(.system(size: 10))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .cornerRadius(10)
    }
}

/// Subscription action box.
struct SubActionBox: View {
    var label: String
    var backgroundColor: Color
    var icon: AnyView
    var iconSize: CGFloat = 20
    var textSize: CGFloat = 8
    var cornerRadius: CGFloat = 10
    var onClick: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .shadow(radius: 3)

            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(backgroundColor)
                        .frame(width: iconSize, height: iconSize)

                    icon
                        .frame(width: 15, height: 15)
                }

                Text(label)
                    .font(.system(size: textSize))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2.5)
        .padding(.vertical, 2)
        .onTapGesture {
            onClick()
        }
    }
}

/// Section info header.
struct SectionInfoView: View {
    var click: (() -> Void)? = nil
    @ObservedObject var boxManager = GlobalBoxModeManager.shared

    var body: some View {
        let backgroundColor = boxManager.mode == AppConstants.BoxModeName.subscribe
            ? Color(red: 0.68, green: 0.97, blue: 0.74).opacity(0.2)
            : Color(red: 0.55, green: 0.75, blue: 0.99).opacity(0.2)

        let text = boxManager.mode == AppConstants.BoxModeName.subscribe
            ? "Managing a push subscription. Click to close"
            : "Profile information. Click to close"

        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .frame(height: 25)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(5)
            .padding(.horizontal, 12)
            .onTapGesture {
                click?()
            }
    }
}

/// Returns the display name for the given screen mode.
///
/// - Parameter mode: Screen mode identifier.
/// - Returns: Localized screen name.
func getBoxName(mode: String) -> String {
    switch mode {
    case AppConstants.BoxModeName.events:
        return "Main events:"
    case AppConstants.BoxModeName.subscribe:
        return "Subscribe to:"
    case AppConstants.BoxModeName.profile:
        return "Profile Info:"
    default:
        return "Main events:"
    }
}

/// Mobile events section box.
struct MobileEventBoxView: View {
    @State private var sid: String = ""
    @State private var eventName: String = ""

    var body: some View {
        VStack(spacing: 15) {
            VStack(spacing: 7) {
                MobileEventTextRow(
                    title: "sid",
                    text: $sid
                )

                MobileEventTextRow(
                    title: "name",
                    text: $eventName
                )
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(Color.white)
            .cornerRadius(10)

            HStack(spacing: 0) {
                MobileEventActionView(
                    text: "Click to send",
                    backgroundColor: Color(
                        red: 0.68,
                        green: 0.97,
                        blue: 0.74
                    ).opacity(0.2),
                    endImageName: "ic_mark_2",
                    endImageRotation: 45,
                    startPadding: 20,
                    endPadding: 2,
                    onClick: {
                        AltcraftSDK.target.sendTarget(
                            sid: sid,
                            eventName: eventName
                        )

                        GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                    }
                )

                MobileEventActionView(
                    text: "Click to close",
                    backgroundColor: Color(
                        red: 0.55,
                        green: 0.75,
                        blue: 0.99
                    ).opacity(0.2),
                    endImageName: "ic_mark_2",
                    endImageRotation: 0,
                    startPadding: 2,
                    endPadding: 20,
                    onClick: {
                        GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                    }
                )
            }

            Spacer().frame(height: 10)
        }
    }
}

/// Mobile event text row.
private struct MobileEventTextRow: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.black)
                    .frame(width: 38, alignment: .leading)

                TextField("", text: $text)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
                    .textFieldStyle(.plain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Divider()
                .background(Color.gray.opacity(0.5))
        }
        .padding(.horizontal, 15)
    }
}

/// Mobile event action row.
private struct MobileEventActionView: View {
    let text: String
    let backgroundColor: Color
    let endImageName: String
    let endImageRotation: Double
    let startPadding: CGFloat
    let endPadding: CGFloat
    let onClick: () -> Void

    var body: some View {
        ZStack {
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineLimit(1)

            Image(endImageName)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(Color.black.opacity(0.5))
                .frame(width: 8, height: 8)
                .rotationEffect(.degrees(endImageRotation))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 25)
        }
        .frame(height: 25)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(5)
        .padding(.leading, startPadding)
        .padding(.trailing, endPadding)
        .onTapGesture {
            onClick()
        }
    }
}
