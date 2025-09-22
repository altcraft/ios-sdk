//
//  ExampleView.swift
//
//  IOSAPNsApp
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI

struct ExampleView: View {
    @ObservedObject var manager = GlobalNotificationDataManager.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header()

            // Notification Card with tap gesture
            VStack {
                // Card content
                VStack {
                    HStack(alignment: .top, spacing: 10) {
                    
                        Image("altlogo")
                            .resizable()
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.title)
                                .font(.system(size: 14, weight: .semibold))

                            Text(manager.body)
                                .font(.system(size: 12.0, weight: .regular))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }

                        if !isExpanded, let image = manager.image {
                            Image(uiImage: image)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    
                    if isExpanded, let large = manager.image {
                        Image(uiImage: large)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                            .clipShape(TopFlatRoundedBottom(radius: 20))
                            .clipped()
                            .padding(.horizontal, -17)
                            .padding(.bottom, -40)
                            .contentShape(Rectangle())
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 3)
            .frame(maxWidth: .infinity, minHeight: 70, alignment: .top)
            .padding(.horizontal, 15)
            .padding(.top, 40)
            
            // Notification Buttons
            VStack(spacing: 10) {
                ForEach(manager.buttons.indices, id: \.self) { index in
                    HStack {
                        Spacer(minLength: 0)

                        Button(action: {}) {
                            Text(manager.buttons[index])
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 30)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, isExpanded ? 20 : 10)
            
            ScrollView {
                VStack(spacing: 25) {
                    Spacer().frame(height: 10)
                    
                    TextSetting()
                    
                    ImageSetting()
                    
                    ButtonsSettingView(manager: manager)
                    
                    SendPushButton()
                    
                    Spacer().frame(height: 20)
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct TextSetting: View {
    @ObservedObject var manager = GlobalNotificationDataManager.shared
    @State private var title: String = ""
    @State private var pushBody: String = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Text setting:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 20) {
                    RemoveButton {
                        title = ""
                        pushBody = ""
                        manager.title = ""
                        manager.body = ""
                    }

                    AddButton {
                        manager.title = title
                        manager.body = pushBody
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)

            GradientShadowLine(colors: [
                Color(red: 0.55, green: 0.75, blue: 0.99, opacity: 0.4),
                Color.black.opacity(0.1),
                Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
            ], height: 3, horizontalPadding: 15)
        }
        .background(Color.white)

        EditTextRow(
            name: "Title",
            text: $title,
            hint: manager.title
        )

        EditTextRow(
            name: "Body",
            text: $pushBody,
            hint: manager.body
        )
    }
}

struct ImageSetting: View {
    @ObservedObject var manager = GlobalNotificationDataManager.shared
    @State private var imgUrl: String = ""
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Image setting:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 20) {
                    RemoveButton {
                        imgUrl = ""
                        manager.setImageUrl(nil)
                    }

                    AddButton {
                        manager.setImageUrl(imgUrl)
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)

            GradientShadowLine(colors: [
                Color(red: 0.55, green: 0.75, blue: 0.99, opacity: 0.4),
                Color.black.opacity(0.1),
                Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
            ], height: 3, horizontalPadding: 15)
        }
        .background(Color.white)

        EditTextRow(
            name: "Image URL",
            text: $imgUrl,
            hint: manager.imageUrl ?? ""
        )
    }
}

struct ButtonsSettingView: View {
    @ObservedObject var manager: NotificationDataManager

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Button setting:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 20) {
                    RemoveButton {
                        manager.buttons = []
                        manager.saveToUserDefaults()
                    }

                    AddButton {
                        let canAdd = manager.buttons.count < 3 &&
                                     (manager.buttons.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || manager.buttons.isEmpty)

                        if canAdd {
                            manager.buttons.append("")
                            manager.saveToUserDefaults()
                        }
                    }
                }
            }
            .padding(.horizontal, 15)
            .padding(.bottom, 10)

            GradientShadowLine(
                colors: [
                    Color(red: 0.55, green: 0.75, blue: 0.99, opacity: 0.4),
                    Color.black.opacity(0.1),
                    Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
                ],
                height: 3,
                horizontalPadding: 15
            )

            if !manager.buttons.isEmpty {
                HStack(spacing: 5) {
                    ForEach(Array(manager.buttons.enumerated()), id: \.offset) { index, text in
                        EditableButtonItem(
                            text: text,
                            onTextChanged: { newText in
                                manager.buttons[index] = newText
                                manager.saveToUserDefaults()
                            },
                            onRemove: {
                                manager.buttons.remove(at: index)
                                manager.saveToUserDefaults()
                            }
                        )
                    }
                }
                .padding(.top, 10)
                .padding(.horizontal, 15)
            }
        }
        .background(Color.white)
    }
}

struct EditableButtonItem: View {
    @State private var editableText: String
    let onTextChanged: (String) -> Void
    let onRemove: () -> Void

    init(text: String, onTextChanged: @escaping (String) -> Void, onRemove: @escaping () -> Void) {
        _editableText = State(initialValue: text)
        self.onTextChanged = onTextChanged
        self.onRemove = onRemove
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            TextField("Button text", text: $editableText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .padding(.trailing, 35)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 1)
                .onChange(of: editableText) { newValue in
                    onTextChanged(newValue)
                }

            Button(action: onRemove) {
                XShapedIcon(
                    lineWidth: 15,
                    lineHeight: 3,
                    firstColor: .black,
                    secondColor: .black
                )
                .padding(.trailing, 10)
            }
        }
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 3)
    }
}



struct TopFlatRoundedBottom: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        path.closeSubpath()

        return path
    }
}

struct SendPushButton: View {
    var body: some View {
        let backgroundColor = Color(red: 0.55, green: 0.75, blue: 0.99).opacity(0.2)
        let text = "Send push"

        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.gray)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(5)
            .padding(.horizontal, 12)
            .onTapGesture {
                GlobalNotificationDataManager.shared.sendPush()
            }
    }
}
