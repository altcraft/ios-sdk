//
//  UserDefaultsSandbox.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

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
