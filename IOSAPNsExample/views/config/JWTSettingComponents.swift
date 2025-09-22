//
//  JWTSettingComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

// MARK: - JWTSettingView
struct JWTSettingView: View {
    @StateObject private var manager = JWTSettingManager()
    @State private var editingAnonJWT: String = ""
    @State private var editingRegJWT: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            VStack(spacing: 0) {
                HStack {
                    Text("JWT setting:")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 20) {
                        RemoveButton {
                            manager.clearJWTs()
                            editingAnonJWT = ""
                            editingRegJWT = ""
                        }
                        
                        AddButton {
                            manager.anonJWT = editingAnonJWT.isEmpty ? manager.anonJWT : editingAnonJWT
                            manager.regJWT = editingRegJWT.isEmpty ? manager.regJWT : editingRegJWT
                            
                            manager.saveJWTs()
                            showSaveConfirmation = true
                            editingAnonJWT = ""
                            editingRegJWT = ""
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
            
            // JWT fields
            EditTextRow(
                name: "A.JWT",
                text: $editingAnonJWT,
                hint: manager.anonJWT.truncatedJWT()
            )
            
            EditTextRow(
                name: "R.JWT",
                text: $editingRegJWT,
                hint: manager.regJWT.truncatedJWT()
            )
            
            Spacer()
        }
        .alert("JWT Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }
}

extension String {
    func truncatedJWT() -> String {
        guard self.count > 40 else { return self }
        
        let prefix = String(self.prefix(17))
        let suffix = String(self.suffix(17))
        return "\(prefix)...\(suffix)"
    }
}
