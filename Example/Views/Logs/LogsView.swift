//
//  LogsView.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import SwiftUI

struct LogsView: View {
    @ObservedObject var eventManager = GlobalEventManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            Header()
   
            Spacer()
            
            if eventManager.events.isEmpty {
                Spacer()
                Text("No events yet")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
                Spacer()
            } else {
                VStack {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(eventManager.events) { event in
                                EventLogItemView(date: event.event.date, message: event.event.message ?? "")
                            }
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct EventLogItemView: View {
    let date: Date?
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let date = date {
                Text(formatDateToTimestampString(date))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.21, green: 0.47, blue: 0.89))
            }

            Text(message)
                .font(.system(size: 10))
                .foregroundColor(.black)
            
            Color.clear.frame(height: 1)
            
            Divider().frame(height: 1).background(Color.gray.opacity(0.2))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color.white)
    }
}

func formatDateToTimestampString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US")
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
}




