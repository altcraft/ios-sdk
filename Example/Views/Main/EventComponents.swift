//
//  EventComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI

struct MainEventsView: View {
    var eventMessage: String
    var eventCode: Int? = nil
    var eventDate: Date? = nil

    private var formattedDate: String? {
        guard let eventDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS" 
        return formatter.string(from: eventDate)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 130, height: 130)
                .shadow(radius: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(eventCode ?? 0)")
                    .foregroundColor(.black)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 10)
                    .offset(x: 15, y: 15)

                Text(eventMessage)
                    .font(.system(size: 10))
                    .frame(width: 90, height: 60, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .offset(x: 15, y: 20)

                Spacer()

                if let date = formattedDate {
                    VStack(spacing: 3) {
                        Divider()
                            .background(Color.gray.opacity(0.3))
                            .padding(.horizontal, 10)

                        Text(date)
                            .font(.system(size: 8))
                            .foregroundColor(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .offset(y: -5)
                }
            }
            .frame(width: 130, height: 130, alignment: .topLeading)
        }
    }
}
