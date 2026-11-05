//
//  InAppStatusManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftCore
import AltcraftPush
import AltcraftInApp
import AltcraftProfile
import AltcraftTarget
import Combine

/// Tracks and displays the in-app subscription status.
@MainActor
final class InAppStatusManager: ObservableObject {

    @Published var status: String

    var isSubscribed: Bool {
        status == AppConstants.SubscriptionStatus.subscribed
    }

    init() {
        self.status = getInAppSubscriptionStatusFromUserDefaults()
    }

    /// Toggles the current in-app subscription status indicator.
    func toggle() {
        if isSubscribed {
            AltcraftSDK.inApp.subscription.unsubscribe()
        } else {
            AltcraftSDK.inApp.subscription.subscribe()
        }
    }

    /// Updates the in-app subscription status from an SDK event.
    ///
    /// - Parameter event: SDK event carrying the subscription state.
    func updateStatus(with event: Event) {
        guard let sdkEvent = event.event else { return }

        if let inApp = sdkEvent as? InAppModuleEvents {
            switch inApp {

            case .inAppSubscribeRequestSuccessful:
                saveStatus(AppConstants.SubscriptionStatus.subscribed)

            case .inAppUnsubscribeRequestSuccessful:
                saveStatus(AppConstants.SubscriptionStatus.unsubscribed)

            case .inAppStatusRequestSuccessful:
                let profile = event.value?["profile"] as? ProfileData
                let newStatus = profile?.subscription?.status
                ?? AppConstants.SubscriptionStatus.unsubscribed

                saveStatus(newStatus)

            default:
                return
            }
        } else if let core = sdkEvent as? CoreEvents {
            switch core {
            case .sdkCleared:
                clearStatus()
            default:
                return
            }
        }
    }

    /// Resets the in-app subscription status indicator to its default.
    func clearStatus() {
        status = AppConstants.SubscriptionStatus.unsubscribed
        setInAppSubscriptionStatusToUserDefaults(AppConstants.SubscriptionStatus.unsubscribed)
    }

    /// Persists the in-app subscription status to UserDefaults.
    ///
    /// - Parameter status: Current subscription status.
    private func saveStatus(_ status: String) {
        self.status = status
        setInAppSubscriptionStatusToUserDefaults(status)
    }
}

/// Shared `InAppStatusManager` singleton.
@MainActor
final class GlobalInAppStatusManager {
    static let shared = InAppStatusManager()
    private init() {}
}
