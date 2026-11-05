//
//  ModuleConfiguration.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Configuration contract of an optional Altcraft SDK module.
///
/// Core stores module configurations without knowing their concrete classes.
/// Each configuration is associated with its module through ``moduleId``,
/// so that core can resolve the configuration of a registered module.
///
/// Mirrors Android `ModuleConfiguration`.
///
/// Conforming types are immutable configuration snapshots, so the protocol
/// requires `Sendable` conformance to be safely crossed into the isolated
/// context of a module worker.
@_spi(_Altcraft) public protocol ModuleConfiguration: Sendable {
    /// Unique module identifier.
    ///
    /// Must match the corresponding ``AltcraftModule/moduleId``.
    var moduleId: String { get }

    /// Provides the concrete module queue worker for this configuration.
    ///
    /// Core stays agnostic of concrete module implementations: each optional
    /// module supplies its own worker through its configuration, allowing
    /// ``ModuleRegistry`` to auto-register the module during SDK initialization.
    ///
    /// - Returns: The module worker, or `nil` if the configuration does not
    ///   provide one and the module is registered lazily through its facade.
    func module() -> (any AltcraftModule)?
}

@_spi(_Altcraft) public extension ModuleConfiguration {
    /// Default implementation provides no worker.
    func module() -> (any AltcraftModule)? { nil }
}

/// Container for module configurations attached to the SDK configuration.
///
/// Used to keep the dictionary of existential module configurations without
/// exposing it to Objective-C.
final class ModuleConfigBox: @unchecked Sendable {

    /// Stored configurations indexed by module identifier.
    var values: [String: any ModuleConfiguration] = [:]

    /// Creates a box with the given configurations.
    ///
    /// - Parameter values: Initial module configurations.
    init(_ values: [String: any ModuleConfiguration] = [:]) {
        self.values = values
    }
}
