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
