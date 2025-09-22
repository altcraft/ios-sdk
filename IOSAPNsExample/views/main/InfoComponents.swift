//
//  InfoComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI


struct InfoItemView: View {
    var title: String
    var imageName: String
    var displayText: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .frame(width: 130, height: 130)
                .shadow(radius: 2)
            
            Text(displayText)
                .font(.system(size: 12))
                .fontWeight(.bold)
                .frame(width: 40, height: 100)
                .multilineTextAlignment(.center)
                .offset(y: 30)
                .offset(x: 50)
            
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .frame(width: 37, height: 37)
                        .shadow(radius: 10)
                    
                    Image(imageName)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                }
                .padding(10)
                
                Text(title)
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .frame(width: 60, height: 25)
                    .offset(x: -10)
            }
        }
    }
}


func createInfoItemView(index: Int, token: String, date: String) -> InfoItemView {
    
    let userName = configSubString(input: getConfigFromUserDefault()?.apiUrl)
    
    switch index {
    case 0:
        return InfoItemView(title: "device token:", imageName: "ic_apns_logo", displayText: token)
    case 1:
        return InfoItemView(title: "update time:", imageName: "ic_time", displayText: date)
    case 2:
        return InfoItemView(title: "user:", imageName: "ic_setting", displayText: userName)
    default:
        return InfoItemView(title: "", imageName: "", displayText: "")
    }
}

struct ModuleCard: View {
    let moduleName: String?
    let imageName: String
    let status: Bool
    let onClick: () -> Void
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .frame(width: 90, height: 60)
                .shadow(radius: 3)
                .onTapGesture { onClick() }

            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 37, height: 37)
                    
                    Image(imageName)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                }
                .offset(x: 0, y: -3)

                VStack(alignment: .leading, spacing: 0) {
                    Text(moduleName ?? "")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .offset(y: 3)

                    Spacer().frame(height: 20)

                    HStack {
                        Text(status == false ? "on" : "off")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer().frame(width: 10)

                        ModuleStatusIndicator(status: status, size: 7)
                    }
                    .offset(y: -7)
                }
            }
            .padding(.top, 7)
            .padding(.leading, 3)
        }
    }
}
