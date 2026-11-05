//
//  ConfigurationView.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import SwiftUI

/// SDK configuration screen entry.
struct ConfigurationView: View {
    
    var body: some View {
        VStack(spacing: 0) {
            Header()
            
            Spacer().frame(height: 20)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    ConfigSettingView()
                        .padding(.top, 5)
                    
                    Spacer().frame(height: 5)
                    
                    JWTSettingView()
                        .padding(.top, 5)
              
                    SubscribeSettingView()
                        .padding(.top, 5)
                    
                    Spacer().frame(height: 10)
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .top)
    }
}

