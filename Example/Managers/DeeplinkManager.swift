//
//  DeeplinkManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import AltcraftPush
import AltcraftTarget

/// Resolves `altcraft.main` deeplinks.
final class DeeplinkManager {

    /// Navigation target resolved from a deeplink.
    enum Target: Equatable {
        case mode(Int) // 1..4
    }

    /// Deeplink scheme constants.
    private enum C {
        static let scheme = "altcraft.main"
    }

    /// Resolves an `altcraft.main` deeplink to a navigation target.
    ///
    /// - Parameter url: Incoming URL.
    /// - Returns: Target screen mode, or `nil` for unknown links.
    func manage(url: URL) -> Target? {
        guard url.scheme == C.scheme else {
            return nil
        }

        switch url.host?.lowercased() {
        case "home":
            return .mode(1)
        case "example":
            return .mode(2)
        case "logs":
            return .mode(3)
        case "config":
            return .mode(5)
        default:
            return nil
        }
    }
}
