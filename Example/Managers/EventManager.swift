//
//  EventManager.swift
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

/// Event wrapper identifiable for list rendering.
struct IdentifiableEvent: Identifiable, Equatable {
    let id = UUID()
    let event: Event
}

/// Collects SDK events for the log screen.
@MainActor
class EventManager: ObservableObject {
    @Published var events: [IdentifiableEvent] = []

    /// Appends an SDK event to the log.
    ///
    /// - Parameter event: Event to store.
    func addEvent(_ event: Event) {
        self.events.append(IdentifiableEvent(event: event))
    }

    /// Clears the stored event log.
    func clearEvents() {
        self.events.removeAll()
    }
}

/// Shared `EventManager` singleton.
@MainActor
class GlobalEventManager {static let shared = EventManager()}

extension AppDelegate {

    /// Subscribes the app to SDK event streams (auth, token,
    /// subscription, in-app).
    func registerAltcraftEventHandlers() {
        AltcraftSDK.sdkEvents.subscribe { event in

            Task { @MainActor in
                GlobalTokenManager.shared.updateToken(with: event)
            }

            Task { @MainActor in
                GlobalPushStatusManager.shared.updateStatus(with: event)
            }

            Task { @MainActor in
                GlobalInAppStatusManager.shared.updateStatus(with: event)
            }

            Task { @MainActor in
                GlobalAuthStatusManager.shared.updateStatus(with: event)
            }

            Task { @MainActor in
                GlobalEventManager.shared.addEvent(event)
            }

            Task { @MainActor in
                GlobalProfileDataManager.shared.fetchProfileData(with: event)
            }
            
            Task { @MainActor in
                GlobalInAppPlacementManager.shared.updateCount(with: event)
            }
        }
    }
}
