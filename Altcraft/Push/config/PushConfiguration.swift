//
//  PushConfiguration.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Configuration for the push module.
///
/// Contains the push provider priority order. Pass an instance to
/// `AltcraftConfiguration.Builder` via ``ConfigExtension/pushConfig(_:)``.
///
/// Mirrors Android `PushConfiguration`.
final class PushConfiguration: ModuleConfiguration {

    /// Push provider identifiers ordered by priority.
    let providerPriority: [String]

    /// Creates a new push module configuration.
    ///
    /// - Parameter providerPriority: Push provider identifiers ordered by priority.
    init(providerPriority: [String] = []) {
        self.providerPriority = providerPriority
    }

    /// Unique push module identifier.
    var moduleId: String { PushConstants.Module.id }

    /// Provides the push module lifecycle controller for automatic registration
    /// during SDK initialization.
    func module() -> (any AltcraftModule)? {
        PushModuleLifecycle.shared
    }

    /// Indicates whether the configured providers are valid.
    ///
    /// - Returns: `true` when every provider identifier is supported.
    func isProviderPriorityValid() -> Bool {
        TokenManager.shared.allProvidersValid(providerPriority)
    }
}
