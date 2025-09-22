//
//  ActionComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI
import Altcraft

struct ActionButton: View {
    var label: String
    var onClick: () -> Void
    var customIcon: (() -> AnyView)? = nil

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .shadow(radius: 5)
                    .onTapGesture { onClick() }

                Circle()
                    .fill(Color.black)
                    .frame(width: 50, height: 50)
                    .shadow(radius: 3)
                    .onTapGesture { onClick() }

                if let customIcon = customIcon {
                    customIcon()
                }
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

            CheckMarkIcon(strokeWidth: 3, strokeColor: checkMarkColor)
        }
        .frame(width: 17, height: 17)
        .rotationEffect(.degrees(rotationDegrees))
    }
}

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
            .stroke(strokeColor, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
        }
    }
}

//Update Icon
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
struct ArcShapeUp: Shape {
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
struct ArcShapeDown: Shape {
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
struct SubBoxView: View {
    var subscribe: Bool
    var rounded: CGFloat = 5
    
    var body: some View {
        VStack {
            HStack(spacing: 2.5) {
                SubActionBox(
                    label: "Subscribe",
                    backgroundColor: Color(hex: "#33FF5F").opacity(0.1),
                    icon: AnyView(PlusIcon(lineWidth: 15, lineHeight: 3, color: Color.black)),
                    onClick: {
                        //SubscribeButton
                        GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                        pushSubscribe()
                        
                    })
                
                Spacer().frame(width: 2.5)
                
                SubActionBox(
                    label: "Suspend",
                    backgroundColor: Color.black.opacity(0.1),
                    icon: AnyView(UShapedIcon(topArcColor: Color.black, bottomArcColor: Color.black)),
                    onClick: {
                        //SuspendButton
                        GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                        pushSuspend()
                    })
                
                Spacer().frame(width: 2.5)
                
                SubActionBox(
                    label: "Unsubscribe",
                    backgroundColor: Color.black.opacity(0.1),
                    icon: AnyView(XShapedIcon(lineWidth: 15, lineHeight: 3, firstColor: Color.black, secondColor: Color.black)),
                    onClick: {
                        //UnsubscribeButton
                        GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                        pushUnsubscribe()
                    })
                
                Spacer().frame(width: 2.5)
                
                VStack(spacing: 5) {
                    SubActionBox(
                        label: "Log In",
                        backgroundColor: Color.black.opacity(0.7),
                        icon: AnyView(CommonIcon(rotationDegrees: -90, circleColor: Color.clear, checkMarkColor: Color.white)),
                        height: 48,
                        circleSize: 23,
                        cornerRadius: 15,
                        onClick: {
                            //LogInButton
                            GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                            logIn()
                        }
                    )
                    
                    SubActionBox(
                        label: "Log Out",
                        backgroundColor: Color.black.opacity(0.7),
                        icon: AnyView(CommonIcon(rotationDegrees: 90, circleColor: Color.clear, checkMarkColor: Color.white)),
                        height: 48,
                        circleSize: 23,
                        cornerRadius: 15,
                        onClick: {
                            //LogOutButton
                            GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
                            logOut()
                        }
                    )
                }
            }
            
            Spacer().frame(height: 15)
            
            SectionInfoView {
                GlobalBoxModeManager.shared.mode = AppConstants.BoxModeName.events
            }
        }
    }
}

struct SubActionBox: View {
    var label: String
    var backgroundColor: Color
    var icon: AnyView
    var width: CGFloat = 85
    var height: CGFloat = 100
    var circleSize: CGFloat = 35
    var cornerRadius: CGFloat = 20
    var onClick: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .frame(width: width, height: height)
                .shadow(radius: 5)

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30)
                        .fill(backgroundColor)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(radius: 3)

                    icon
                        .frame(width: 15, height: 15)
                }

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(.black)
            }
        }
        .onTapGesture {
            onClick()
        }
    }
}

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
