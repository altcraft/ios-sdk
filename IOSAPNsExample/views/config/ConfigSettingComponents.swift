//
//  ConfigSettingComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI


// MARK: - ConfigSettingView

struct ConfigSettingView: View {
    @StateObject private var manager = ConfigSettingManager()
    @State private var editingApiUrl: String = ""
    @State private var editingRToken: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text("Config setting:")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 20) {
                        RemoveButton {
                            manager.resetConfig()
                            editingApiUrl = ""
                            editingRToken = ""
                        }
                        
                        AddButton {
                            manager.apiUrl = editingApiUrl.isEmpty ? manager.apiUrl : editingApiUrl
                            manager.rToken = editingRToken.isEmpty ? manager.rToken : editingRToken
                            manager.saveConfig { success in
                                if success {
                                    initSDK(config: getConfigFromUserDefault())
                                }
                            }
                            
                            editingApiUrl = ""
                            editingRToken = ""
    
                            showSaveConfirmation = true
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
            
            // Config fields
            EditTextRow(
                name: "API url",
                text: $editingApiUrl,
                hint: manager.apiUrl.isEmpty ? "" : manager.apiUrl
            )
            
            EditTextRow(
                name: "RToken",
                text: $editingRToken,
                hint: manager.rToken.isEmpty ? "" : manager.rToken
            )
            
            // Providers selection
            ProviderSelectionBox(manager: manager)
            
            Spacer()
        }
        .alert("Configuration Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }
}

// MARK: - ProviderSelectionBox

struct ProviderSelectionBox: View {
    @ObservedObject var manager: ConfigSettingManager
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom) {
                Spacer().frame(width: 10)

                Text("Providers")
                    .font(.system(size: 8))
                    .foregroundColor(.black)

                Spacer()
            }
            .frame(height: 25)

            VStack(spacing: 10) {
                if !$manager.providers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(manager.providers, id: \.self) { provider in
                                ProviderChip(provider: provider) {
                                    manager.removeProvider(provider)
                                }.padding(.vertical, 3)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                
                HStack(spacing: 8) {
                    ProviderSelectionButton(displayName: "APNs", iconName: "ic_apns_logo") {
                        manager.addProvider(.apns)
                    }
                    
                    ProviderSelectionButton(displayName: "FCM", iconName: "ic_fcm_logo") {
                        manager.addProvider(.fcm)
                    }

                    ProviderSelectionButton(displayName: "HMS", iconName: "ic_hms_logo") {
                        manager.addProvider(.hms)
                    }
                }
            }
            .padding(8)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 1)
        }
        .padding(.horizontal, 15)
    }
}

// MARK: - Provider Chip Component

struct ProviderChip: View {
    let provider: Provider
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(provider.iconName)
                .resizable()
                .renderingMode(.template)
                .foregroundColor(.black)
                .frame(width: 16, height: 16)
                .padding(.vertical, 2)
            
            Text(provider.displayName)
                .font(.system(size: 12))
                .foregroundColor(.black)
                .fixedSize()
            
            Image(systemName: "xmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(radius: 2)
        .onTapGesture {
            onRemove()
        }
    }
}

// MARK: - Provider Selection Button

struct ProviderSelectionButton: View {
    let displayName: String
    let iconName: String
    let onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack {
                Image(iconName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(.black)
                    .frame(width: 20, height: 20)
                
                Text(displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
        }
    }
}
