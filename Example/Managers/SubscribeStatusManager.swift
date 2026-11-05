//
//  SubscribeStatusManager.swift
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

/// Tracks and displays the push subscription status.
@MainActor
final class PushStatusManager: ObservableObject {

    @Published var status: String

    var isSubscribed: Bool {
        status == AppConstants.SubscriptionStatus.subscribed
    }

    init() {
        self.status = getPushSubscriptionStatusFromUserDefaults()
    }

    /// Toggles the current push subscription status indicator.
    func toggle() {
        if isSubscribed {
            AltcraftSDK.push.subscription.unsubscribe()
        } else {
            AltcraftSDK.push.subscription.subscribe()
        }
    }

    /// Updates the push subscription status from an SDK event.
    ///
    /// - Parameter event: SDK event carrying the subscription state.
    func updateStatus(with event: Event) {
        guard let sdkEvent = event.event else { return }

        if let push = sdkEvent as? PushModuleEvents {
            switch push {

            case .pushSubscribeRequestSuccessful,
                 .pushSuspendRequestSuccessful,
                 .pushUnsubscribeRequestSuccessful,
                 .pushStatusRequestSuccessful,
                 .unsuspendRequestSuccessful:

                let profile = event.value?["profile"] as? ProfileData
                let newStatus = profile?.subscription?.status
                ?? AppConstants.SubscriptionStatus.unsubscribed

                saveStatus(newStatus)

            case .pushStatusRequestFailed:

                let eventValue = event.value
                let responseWithHttp = eventValue?["responseWithHttp"]

                let responseText = String(describing: responseWithHttp)

                if responseText.contains("profile not found") ||
                    responseText.contains("Profile not found") {
                    saveStatus(AppConstants.SubscriptionStatus.unsubscribed)
                }

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

    /// Resets the push subscription status indicator to its default.
    func clearStatus() {
        status = AppConstants.SubscriptionStatus.unsubscribed
        setPushSubscriptionStatusToUserDefaults(AppConstants.SubscriptionStatus.unsubscribed)
    }

    /// Persists the push subscription status to UserDefaults.
    ///
    /// - Parameter status: Current subscription status.
    private func saveStatus(_ status: String) {
        self.status = status
        setPushSubscriptionStatusToUserDefaults(status)
    }
}

/// Shared `PushStatusManager` singleton.
@MainActor
final class GlobalPushStatusManager {
    static let shared = PushStatusManager()
    private init() {}
}
