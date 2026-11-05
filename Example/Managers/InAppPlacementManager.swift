//
//  InAppPlacementManager.swift
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
import Combine

/// Tracks in-app placement counts.
@MainActor
final class InAppPlacementManager: ObservableObject {

    @Published var placementCount: Int = 0

    /// Updates the placement counter from an SDK event.
    ///
    /// - Parameter event: SDK event carrying the placement update.
    func updateCount(with event: Event) {
        guard let sdkEvent = event.event else { return }

        if let inApp = sdkEvent as? InAppModuleEvents {
            switch inApp {

            case .inAppPlacementsRequestSuccessful:
                let smids = event.value?["allSmidKey"] as? [String]
                placementCount = smids?.count ?? 0

            default:
                return
            }
        } else if let core = sdkEvent as? CoreEvents {
            switch core {
            case .sdkCleared:
                placementCount = 0
            default:
                return
            }
        }
    }
}

/// Shared `InAppPlacementManager` singleton.
@MainActor
final class GlobalInAppPlacementManager {
    static let shared = InAppPlacementManager()
    private init() {}
}
