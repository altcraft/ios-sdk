//
//  ConfigExtension.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Adds the push module configuration to the SDK builder.
public extension AltcraftConfiguration.Builder {

    /// Adds a push module configuration.
    ///
    /// - Parameter configuration: Push module configuration.
    /// - Returns: This builder for chained calls.
    @discardableResult
    internal func pushConfig(_ configuration: PushConfiguration) -> Self {
        addModuleConfiguration(configuration)
        return self
    }

    /// Adds a push module configuration.
    ///
    /// - Parameter providerPriority: Push provider identifiers ordered by priority.
    /// - Returns: This builder for chained calls.
    @discardableResult
    func pushConfig(providerPriority: [String] = []) -> Self {
        addModuleConfiguration(
            PushConfiguration(providerPriority: providerPriority)
        )
        return self
    }

    /// Objective-C compatible push module configuration.
    ///
    /// - Parameter providerPriority: Push provider identifiers ordered by priority.
    /// - Returns: This builder for chained calls.
    @objc(pushConfigProviderPriority:)
    @discardableResult
    func objcPushConfig(providerPriority: [String]) -> Self {
        addModuleConfiguration(
            PushConfiguration(providerPriority: providerPriority)
        )
        return self
    }
}
