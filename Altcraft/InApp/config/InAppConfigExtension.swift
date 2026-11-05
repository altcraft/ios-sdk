//
//  InAppConfigExtension.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Adds the in-app module configuration to the SDK builder.
public extension AltcraftConfiguration.Builder {

    /// Adds an in-app module configuration.
    ///
    /// - Parameter configuration: In-app module configuration.
    /// - Returns: This builder for chained calls.
    @discardableResult
    internal func inAppConfig(_ configuration: InAppConfiguration) -> Self {
        addModuleConfiguration(configuration)
        return self
    }

    /// Adds an in-app module configuration using individual parameters.
    ///
    /// Mirrors Android `inAppConfig(inAppAutoRequest:placementsRequestInterval:maxPlacements:)`.
    /// The interval is expressed as a `Measurement<UnitDuration>` (for example
    /// `Measurement(value: 10, unit: .minutes)`), and is converted to
    /// milliseconds internally.
    ///
    /// - Parameters:
    ///   - inAppAutoRequest: If `true`, in-app handling is requested on SDK
    ///     initialization.
    ///   - placementsRequestInterval: Interval between automatic placements
    ///     requests.
    ///   - maxPlacements: Maximum number of placements kept in local storage.
    /// - Returns: This builder for chained calls.
    @discardableResult
    func inAppConfig(
        inAppAutoRequest: Bool = true,
        placementsRequestInterval: Measurement<UnitDuration>
            = .init(
                value: Double(InAppConstants.PlacementsConfig.requestIntervalSeconds),
                unit: .seconds
            ),
        maxPlacements: Int = InAppConstants.PlacementsConfig.maxPlacements
    ) -> Self {
        let configuration = InAppConfiguration(
            inAppAutoRequest: inAppAutoRequest,
            placementsRequestInterval: placementsRequestInterval,
            maxPlacements: maxPlacements
        )
        addModuleConfiguration(configuration)
        return self
    }

    /// Objective-C compatible in-app module configuration.
    ///
    /// - Parameters:
    ///   - inAppAutoRequest: If `true`, in-app handling is requested on SDK initialization.
    ///   - placementsRequestIntervalSeconds: Interval between automatic placements
    ///     requests, in seconds.
    ///   - maxPlacements: Maximum number of placements kept in local storage.
    /// - Returns: This builder for chained calls.
    @objc(inAppConfigAutoRequest:PlacementsRequestIntervalSeconds:MaxPlacements:)
    @discardableResult
    func objcInAppConfig(
        inAppAutoRequest: Bool,
        placementsRequestIntervalSeconds: Double,
        maxPlacements: Int
    ) -> Self {
        let configuration = InAppConfiguration(
            inAppAutoRequest: inAppAutoRequest,
            placementsRequestInterval: .init(
                value: placementsRequestIntervalSeconds,
                unit: .seconds
            ),
            maxPlacements: maxPlacements
        )
        addModuleConfiguration(configuration)
        return self
    }
}
