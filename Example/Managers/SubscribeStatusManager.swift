//
//  StatusManager.swift
//  Example
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import SwiftUI
import Combine
import Altcraft

@MainActor
/// Class to manage the subscription status with persistence using UserDefaults
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
    
    /// Update the status based on the provided event
    func updateStatus(with event: Event) {
        let code = event.eventCode ?? 0
        let eventValue = event.value?["response_with_http_code"] as? ResponseWithHttp

        let statusUpdateCodes: Set<Int> = [230, 231, 232, 235]

        if statusUpdateCodes.contains(code) {
            status = eventValue?.response?.profile?.subscription?.status
                ?? AppConstants.SubscriptionStatus.unsubscribed
            UserDefaults.standard.set(status, forKey: "subscribeStatus")
            return
        }

        if code == 433,
           event.message?.range(of: "profile not found", options: [.caseInsensitive]) != nil {
            status = AppConstants.SubscriptionStatus.unsubscribed
            UserDefaults.standard.set(status, forKey: "subscribeStatus")
        }
    }
}

@MainActor
/// Global singleton for accessing the StatusManager
class GlobalStatusManager { static let shared = SubscribeStatusManager() }
