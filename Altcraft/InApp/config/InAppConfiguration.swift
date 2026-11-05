//
//  InAppConfiguration.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Configuration for the in-app module.
///
/// Pass an instance to `AltcraftConfiguration.Builder` via
/// ``ConfigExtension/inAppConfig(_:)``.
///
/// Mirrors Android `InAppConfiguration`.
final class InAppConfiguration: ModuleConfiguration, @unchecked Sendable {

    /// Whether in-app handling is requested on SDK initialization.
    let inAppAutoRequest: Bool

    /// Interval between automatic in-app placements requests, in milliseconds.
    ///
    /// A new automatic request is not sent while this interval has not yet
    /// elapsed since the last successful request.
    let placementsRequestInterval: Int64

    /// Maximum number of in-app placements kept in local storage.
    ///
    /// When a response contains more placements than this limit, only the
    /// newest `[maxPlacements]` entries are stored.
    let maxPlacements: Int

    /// Creates a new in-app module configuration from primitives.
    ///
    /// - Parameters:
    ///   - inAppAutoRequest: If `true`, in-app handling is requested on SDK
    ///     initialization.
    ///   - placementsRequestInterval: Interval between automatic placements
    ///     requests, in milliseconds.
    ///   - maxPlacements: Maximum number of placements kept in local storage.
    init(
        inAppAutoRequest: Bool = true,
        placementsRequestInterval: Int64 = InAppConstants.PlacementsConfig.requestIntervalMs,
        maxPlacements: Int = InAppConstants.PlacementsConfig.maxPlacements
    ) {
        self.inAppAutoRequest = inAppAutoRequest
        self.placementsRequestInterval = placementsRequestInterval
        self.maxPlacements = maxPlacements
    }

    /// Creates a new in-app module configuration using a duration for the
    /// automatic request interval.
    ///
    /// - Parameters:
    ///   - inAppAutoRequest: If `true`, in-app handling is requested on SDK
    ///     initialization.
    ///   - placementsRequestInterval: Interval between automatic placements
    ///     requests, expressed as a `Measurement<UnitDuration>`.
    ///   - maxPlacements: Maximum number of placements kept in local storage.
    convenience init(
        inAppAutoRequest: Bool = true,
        placementsRequestInterval: Measurement<UnitDuration>,
        maxPlacements: Int = InAppConstants.PlacementsConfig.maxPlacements
    ) {
        self.init(
            inAppAutoRequest: inAppAutoRequest,
            placementsRequestInterval: Self.milliseconds(from: placementsRequestInterval),
            maxPlacements: maxPlacements
        )
    }

    /// Unique in-app module identifier.
    var moduleId: String { InAppConstants.Module.id }

    /// Indicates whether the in-app configuration is valid.
    var valid: Bool {
        maxPlacements >= 1 && placementsRequestInterval > 0
    }

    /// Emits an invalidity event when the configuration is invalid.
    ///
    /// Mirrors Android `InAppConfiguration.error()`: a non-positive request
    /// interval or a `maxPlacements` below one is reported via its own
    /// `SDKEvent`. Only the most severe violation is emitted.
    func error() {
        if placementsRequestInterval <= 0 {
            InAppLog.error(#function, error: InAppModuleEvents.requestIntervalInvalid)
        } else if maxPlacements < 1 {
            InAppLog.error(#function, error: InAppModuleEvents.maxPlacementsInvalid)
        }
    }

    /// Provides the in-app module lifecycle controller for automatic registration
    /// during SDK initialization.
    func module() -> (any AltcraftModule)? {
        InAppModuleLifecycle.shared
    }

    /// Converts a duration into whole milliseconds.
    static func milliseconds(from duration: Measurement<UnitDuration>) -> Int64 {
        Int64(duration.converted(to: .milliseconds).value.rounded())
    }
}
