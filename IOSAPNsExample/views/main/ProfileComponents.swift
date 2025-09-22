//
//  ProfileComponents.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import SwiftUI
import Altcraft


struct ProfileBoxView: View {
    @ObservedObject var profileManager = GlobalProfileDataManager.shared
    @ObservedObject var boxManager = GlobalBoxModeManager.shared
    
    var body: some View {
        VStack {
            ProfileDataView(
                profileData: profileManager.profileData,
                errorMessage: profileManager.error,
                isLoading: false
            )
            .padding(.horizontal, 10)
            
            Spacer().frame(height: 15)
            
            SectionInfoView {
                boxManager.mode = AppConstants.BoxModeName.events
            }
            
            Spacer().frame(height: 10)
        }
    }
}

struct ProfileDataView: View {
    var profileData: ProfileData?
    var errorMessage: String?
    var isLoading: Bool

    var body: some View {
        Group {
            if !isLoading {
                if let profileData = profileData {
                    profileContent(profileData: profileData)
                } else {
                    Text(errorMessage ?? "Profile data is null")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                }
            } else {
                LoadingIndicatorView()
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(5)
        .shadow(radius: 1)
    }

    @ViewBuilder
    private func profileContent(profileData: ProfileData) -> some View {
        ScrollView {
            VStack(spacing: 4) {
                ProfileDataItem(label: "ID", value: profileData.id)
                ProfileDataItem(label: "Status", value: profileData.status)
                ProfileDataItem(label: "Is Test", value: profileData.isTest?.description)

                if let subscription = profileData.subscription {
                    subscriptionContent(subscription: subscription)
                }
            }
            .padding(8)
        }
    }

    @ViewBuilder
    private func subscriptionContent(subscription: SubscriptionData) -> some View {
        Spacer().frame(height: 5)
        GradientShadowLine()

        Text("Subscription:")
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)

        Spacer().frame(height: 5)

        ProfileDataItem(label: "Subscription ID", value: subscription.subscriptionId)
        ProfileDataItem(label: "Hash ID", value: subscription.hashId)
        ProfileDataItem(label: "Provider", value: subscription.provider)
        ProfileDataItem(label: "Status", value: subscription.status)

        if let cats = subscription.cats {
            categoriesContent(cats: cats)
        }

        if let fields = subscription.fields {
            fieldsContent(fields: fields)
        }
    }

    @ViewBuilder
    private func categoriesContent(cats: [CategoryData]) -> some View {
        Spacer().frame(height: 5)
        GradientShadowLine()

        Text("Categories:")
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)

        Spacer().frame(height: 5)

        ForEach(cats, id: \.name) { category in
            ProfileDataItem(label: "Name", value: category.name)
            ProfileDataItem(label: "Title", value: category.title)
            ProfileDataItem(label: "Steady", value: category.steady?.description)
            ProfileDataItem(label: "Active", value: category.active?.description)
            Spacer().frame(height: 4)
        }
    }

    @ViewBuilder
    private func fieldsContent(fields: [String: Any]) -> some View {
        Spacer().frame(height: 5)
        GradientShadowLine()

        Text("Fields:")
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)

        Spacer().frame(height: 5)

        ForEach(fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
            ProfileDataItem(label: key, value: String(describing: value))
        }
    }
}


struct ProfileDataItem: View {
    let label: String
    let value: String?
    
    var displayedValue: String {
        if label == "Subscription ID", let value = value, value.count > 30 {
            let head = String(value.prefix(15))
            let tail = String(value.suffix(15))
            return "\(head)...\(tail)"
        }
        return value ?? "null"
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(displayedValue)
                .font(.system(size: 10))
                .foregroundColor(.black)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

func formatFieldValue(_ value: Any) -> String {
    switch value {
    case let str as String:
        return str
    case let bool as Bool:
        return bool ? "true" : "false"
    case let int as Int:
        return String(int)
    case let double as Double:
        return String(double)
    case let dict as [String: Any]:
        return "{\(dict.count) fields}"
    case let array as [Any]:
        return "[\(array.count) items]"
    case is NSNull:
        return "null"
    default:
        return "unknown"
    }
}

struct GradientShadowLine: View {
    var colors: [Color] = [
        Color(red: 0.55, green: 0.75, blue: 0.99, opacity: 0.4),
        Color.black.opacity(0.1),
        Color.black.opacity(0.1)
    ]
    var height: CGFloat = 3
    var horizontalPadding: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                gradient: Gradient(colors: colors),
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: height)
            .cornerRadius(height / 2)
            .padding(.horizontal, horizontalPadding)
    }
}

struct LoadingIndicatorView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .tint(Color.blue)
                .scaleEffect(1.8)
                .padding()
        }
    }
}
