//
//  EventManager.swift
//
//  IOSAPNsExample
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import Combine
import Altcraft

struct IdentifiableEvent: Identifiable, Equatable {
    let id = UUID()
    let event: Event
}

@MainActor
class EventManager: ObservableObject {
    @Published var events: [IdentifiableEvent] = []

    func addEvent(_ event: Event) {
        self.events.append(IdentifiableEvent(event: event))
    }

    func clearEvents() {
        self.events.removeAll()
    }
}

@MainActor
class GlobalEventManager {static let shared = EventManager()}


extension AppDelegate {
    /// Registers event handlers for Altcraft SDK events.
    func registerAltcraftEventHandlers() {
        AltcraftSDK.shared.eventSDKFunctions.subscribe { event in
            // Delegate token handling to TokenManager
            Task { @MainActor in
                GlobalTokenManager.shared.updateToken(with: event)
            }
            
            // Delegate status handling to StatusManager
            Task { @MainActor in
                GlobalStatusManager.shared.updateStatus(with: event)
            }
            
            // Add event to the global event manager
            Task { @MainActor in
                GlobalEventManager.shared.addEvent(event)
            }
            
            // Add profile data to the global manager
            Task { @MainActor in
                GlobalProfileDataManager.shared.fetchProfileData(with: event)
            }
        }
    }
}
