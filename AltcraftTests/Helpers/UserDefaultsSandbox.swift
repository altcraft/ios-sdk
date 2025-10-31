//
//  UserDefaultsSandbox.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Isolated UserDefaults suite for tests.
public final class UserDefaultsSandbox {
    public let suiteName: String
    public let defaults: UserDefaults

    /// Creates a fresh suite and clears it.
    public init(suiteName: String = "AltcraftTests.\(UUID().uuidString)") {
        self.suiteName = suiteName
        guard let d = UserDefaults(suiteName: suiteName) else {
            fatalError("Couldn't create UserDefaults suite \(suiteName)")
        }
        self.defaults = d
        clear()
    }

    /// Removes all keys from the suite.
    public func clear() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }
}
