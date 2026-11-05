//
//  InAppDisplayType.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Defines native in-app display type.
///
/// Values are mapped from backend `displayType`.
@available(iOSApplicationExtension, unavailable)
internal enum InAppDisplayType: String {

    /// Fullscreen in-app display.
    case fullscreen = "fullscreen"

    /// Modal in-app display.
    case modal = "modal"

    /// Slide-up in-app display.
    case slideUp = "slideup"

    /// Floating bar in-app display.
    case floatingBar = "floating_bar"

    /// Custom in-app display.
    case custom = "custom"

    /// Maps a raw backend value to [InAppDisplayType].
    ///
    /// Unknown or missing values are treated as [fullscreen].
    ///
    /// - Parameter value: Raw display type received from backend.
    /// - Returns: Resolved native display type.
    static func from(_ value: String?) -> InAppDisplayType {
        guard let value else {
            return .fullscreen
        }

        return InAppDisplayType(
            rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ) ?? .fullscreen
    }
}

