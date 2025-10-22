//
//  ContentView.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI

struct ContentView: View {
    @Binding var mode: Int

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch mode {
                case 1: MainView()
                case 2: ExampleView()
                case 3: LogsView()
                case 4: ConfigurationView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)

            NavigatorView(mode: $mode)
                .frame(height: 60)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .background(Color.white)
    }
}
