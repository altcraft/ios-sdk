//
//  SubscriptionSettingComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct SubscribeSettingView: View {
    @ObservedObject var manager = SubscribeSettingManager()
    @State private var showCustomFieldsAddBox = false
    @State private var showProfileFieldsAddBox = false
    @State private var showCatsAddBox = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Color.white
                
                VStack(spacing: 0) {
                    HStack {
                        Text("Subscribe setting:")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 20) {
                            RemoveButton {
                                manager.clearSettings()
                            }
                            
                            AddButton {
                                manager.saveSettings()
                            }
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    
                    GradientShadowLine(colors: [
                        Color(red: 0.55, green: 0.75, blue: 0.99, opacity: 0.4),
                        Color.black.opacity(0.1),
                        Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
                    ], height: 3, horizontalPadding: 15)
                }
            }
            
            Spacer().frame(height: 10)
            
            // Content
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    // Sync Switch
                    VStack(spacing: 0) {
                        HStack {
                            Switch(text: "sync", isChecked: $manager.sync)
                            
                            Text("It is necessary to give a synchronous response")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 20)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.5))
                            .padding(.leading, 55)
                            .padding(.trailing, 15)
                            .padding(.top, 4)
                    }
                    
                    Spacer().frame(height: 10)
                    
                    // Replace Switch
                    VStack(spacing: 0) {
                        HStack {
                            Switch(text: "replace", isChecked: $manager.replace)
                            
                            Text("Suspends other subscriptions in the database")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 20)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.5))
                            .padding(.leading, 55)
                            .padding(.trailing, 15)
                            .padding(.top, 4)
                    }
                    
                    Spacer().frame(height: 10)
                    
                    // Skip Triggers Switch
                    VStack(spacing: 0) {
                        HStack {
                            Switch(text: "skipTriggers", isChecked: $manager.skipTriggers)
                            
                            Text("An instruction to ignore company triggers")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 20)
                        }
                        
                        Divider()
                            .background(Color.gray.opacity(0.5))
                            .padding(.leading, 55)
                            .padding(.trailing, 15)
                            .padding(.top, 4)
                    }
                    
                    Spacer().frame(height: 15)
                    
                    // Fields & Cats section title
                    Text("Fields & Cats values:")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.leading, 13)
                        .offset(y: 5)
                    
                    Spacer().frame(height: 15)
                    
                    // Custom Fields Section
                    EditTextRow(
                        name: "C.Fields",
                        text: .constant(""),
                        hint: manager.subscribeSettings.customFieldsString
                    )
                    
                    if showCustomFieldsAddBox {
                        AddKeyValueBox(
                            manager: manager,
                            onAdd: { key, value in
                                manager.addCustomField(key: key, value: value)
                            },
                            isPresented: $showCustomFieldsAddBox
                        )
                    } else {
                        RemoveFieldsBox(
                            fields: manager.subscribeSettings.customFields,
                            onFieldRemoved: { key in
                                manager.removeCustomField(key: key)
                            },
                            onAddClick: {
                                showCustomFieldsAddBox = true
                            }
                        )
                    }
                    
                    Spacer().frame(height: 7)
                    
                    // Profile Fields Section
                    EditTextRow(
                        name: "P.Fields",
                        text: .constant(""),
                        hint: manager.subscribeSettings.profileFieldsString
                    )
                    
                    if showProfileFieldsAddBox {
                        AddKeyValueBox(
                            manager: manager,
                            onAdd: { key, value in
                                manager.addProfileField(key: key, value: value)
                            },
                            isPresented: $showProfileFieldsAddBox
                        )
                    } else {
                        RemoveFieldsBox(
                            fields: manager.subscribeSettings.profileFields,
                            onFieldRemoved: { key in
                                manager.removeProfileField(key: key)
                            },
                            onAddClick: {
                                showProfileFieldsAddBox = true
                            }
                        )
                    }
                    
                    Spacer().frame(height: 7)
                    
                    // Cats Section
                    EditTextRow(
                        name: "Cats",
                        text: .constant(""),
                        hint: manager.subscribeSettings.catsString
                    )
                    
                    if showCatsAddBox {
                        AddKeyValueBox(
                            manager: manager,
                            onAdd: { key, value in
                                manager.addCat(name: key, active: (value as NSString).boolValue)
                            },
                            isPresented: $showCatsAddBox
                        )
                    } else {
                        RemoveFieldsBox(
                            fields: manager.subscribeSettings.catsDictionary,
                            onFieldRemoved: { key in
                                manager.removeCat(name: key)
                            },
                            onAddClick: {
                                showCatsAddBox = true
                            }
                        )
                    }
                }
                .padding(.leading, 10)
                
                Spacer()
            }
        }
        .background(Color.white)
    }
}

// Helper views

struct Switch: View {
    let text: String
    @Binding var isChecked: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                isChecked.toggle()
            }) {
                ZStack {
                    // Track
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 40, height: 24)
                        .shadow(radius: 1.5)
                    
                    // Thumb
                    Circle()
                        .fill(Color.black)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(
                                    isChecked ?
                                    Color(red: 173/255, green: 247/255, blue: 189/255) :
                                    Color(red: 141/255, green: 191/255, blue: 252/255),
                                    lineWidth: 1.5
                                )
                        )
                        .offset(x: isChecked ? 8 : -8)
                }
                .frame(width: 40, height: 24)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.black)
        }
    }
}

struct RemoveFieldsBox: View {
    let fields: [String: String]
    let onFieldRemoved: (String) -> Void
    let onAddClick: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 1)
            
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(fields.keys), id: \.self) { key in
                            FieldChip(key: key, onRemove: {
                                onFieldRemoved(key)
                            })
                        }.padding(.horizontal, 3)
                    }
                    .padding(.vertical, 8)
                }
                
                AddButton(
                    action: onAddClick,
                    buttonSize: 20,
                    iconSize: 15,
                    iconBackgroundColor: Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
                )
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 36)
        .padding(.trailing, 10)
    }
}

struct FieldChip: View {
    let key: String
    let onRemove: () -> Void
    
    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(key)
                    .font(.system(size: 10))
                    .lineLimit(1)
                
                Spacer().frame(width: 5)
                
                XShapedIcon(lineWidth: 2, lineHeight: 10, firstColor: .black, secondColor: .black)
            }
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


struct AddKeyValueBox: View {
    @ObservedObject var manager: SubscribeSettingManager
    let onAdd: (String, String) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 1)

            HStack(spacing: 8) {
                TextField("Key", text: $manager.newFieldKey)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )

                TextField("Value", text: $manager.newFieldValue)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )

                AddButton(
                    action: {
                        if !manager.newFieldKey.isEmpty && !manager.newFieldValue.isEmpty {
                            onAdd(manager.newFieldKey, manager.newFieldValue)
                            manager.newFieldKey = ""
                            manager.newFieldValue = ""
                        }
                        isPresented = false
                    },
                    buttonSize: 20,
                    iconSize: 19,
                    iconBackgroundColor: Color(red: 173/255, green: 247/255, blue: 189/255).opacity(0.4)
                )
                .frame(width: 32)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
