//
//  StatusManager.swift
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import SwiftUI
import Combine
import Altcraft

@MainActor
// Class to manage the subscription status with persistence using UserDefaults
class SubscribeStatusManager: ObservableObject {
    @Published var status: String
    
    init() {
        self.status = UserDefaults.standard.string(forKey: "subscribeStatus") ?? 
        AppConstants.SubscriptionStatus.unsubscribed
    }
    
    /// Clears the stored subscription status from UserDefaults and resets the current status.
    func clearStatus() {
        UserDefaults.standard.removeObject(forKey: "subscribeStatus")
        self.status = AppConstants.SubscriptionStatus.unsubscribed
    }
    
    // Update the status based on the provided event
    func updateStatus(with event: Event) {
        let eventCode = event.eventCode ?? 0
        let eventValue = event.value?["response_with_http_code"] as? ResponseWithHttp
        
        
        if eventCode == 230 || eventCode == 234 {
            self.status =  eventValue?.response?.profile?.subscription?.status ??
            AppConstants.SubscriptionStatus.unsubscribed
            UserDefaults.standard.set(status, forKey: "subscribeStatus")
        }
    }
}

@MainActor
// Global singleton for accessing the StatusManager
class GlobalStatusManager { static let shared = SubscribeStatusManager() }
