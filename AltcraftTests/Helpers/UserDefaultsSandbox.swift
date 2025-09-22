//
//  UserDefaultsSandbox.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

public final class UserDefaultsSandbox {
    public let suiteName: String
    public let defaults: UserDefaults

    public init(suiteName: String = "AltcraftTests.\(UUID().uuidString)") {
        self.suiteName = suiteName
        guard let d = UserDefaults(suiteName: suiteName) else {
            fatalError("Не удалось создать UserDefaults suite \(suiteName)")
        }
        self.defaults = d
        clear()
    }

    public func clear() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults.synchronize()
    }
}
