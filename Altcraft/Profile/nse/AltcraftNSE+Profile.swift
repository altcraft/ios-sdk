//
//  AltcraftNSE+Profile.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Profile NSE APIs.
///
/// Available when the `AltcraftProfile` module (Pod / SPM product) is present.
public extension AltcraftNSE {

    /// Updates the user profile fields on the Altcraft platform.
    ///
    /// This is the NSE-friendly version of
    /// ``UpdateAPI/updateProfileFields(profileFields:skipTriggers:)``.
    /// It forwards to ``UpdateAPI/shared``.
    ///
    /// - Parameters:
    ///   - profileFields: Optional profile fields to update. Values must be
    ///     primitive (String, Number, Bool). Nested objects are rejected and an
    ///     event is logged.
    ///   - skipTriggers: If `true`, server-side automation triggers are skipped
    ///     for this update.
    static func updateProfileFields(
        profileFields: [String: Any?]? = nil,
        skipTriggers: Bool? = nil
    ) {
        UpdateAPI.shared.updateProfileFields(
            profileFields: profileFields,
            skipTriggers: skipTriggers
        )
    }
}
