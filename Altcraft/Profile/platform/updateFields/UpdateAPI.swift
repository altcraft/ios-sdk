//
//  UpdateAPI.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Public API for updating Altcraft profile fields.
@objcMembers
@objc(PublicProfileFunctions)
public final class UpdateAPI: NSObject, @unchecked Sendable {

    public static let shared: UpdateAPI = {
        Profile.ensureRegistered()
        return UpdateAPI()
    }()

    /// Updates profile fields on the server.
    ///
    /// - Parameters:
    ///   - profileFields: Optional profile fields to update.
    ///   - skipTriggers: If `true`, server-side triggers are skipped for this update.
    @nonobjc
    public func updateProfileFields(
        profileFields: [String: Any?]? = nil,
        skipTriggers: Bool? = nil
    ) {

        if (profileFields ?? [:]).containsNonPrimitiveValues() {
            ProfileLog.error(#function, error: CoreEvents.fieldsIsObjects)
            return
        }

        let profileFieldsData = encodeAnyMap(profileFields)

        ProfileUpdateQueues.entityQueue.submit {
            await ProfileUpdateProcess.shared.updateProfileFields(
                profileFields: profileFieldsData,
                skipTriggers: skipTriggers ?? false
            )
        }
    }

    // MARK: - Objective-C bridge (hidden from Swift)
    //
    // Selector in ObjC:
    //  profileUpdate:
    //  skipTriggers:
    //
    // Notes:
    // - ObjC can't pass `nil` for a primitive BOOL, so we accept `NSNumber?`.
    /// Objective-C entry point for
    /// `updateProfileFields(profileFields:skipTriggers:)`.
    ///
    /// - Parameters:
    ///   - profileFields: Profile fields as a key-value dictionary.
    ///   - skipTriggers: `NSNumber` boolean; `true` skips automation triggers.
    @available(swift, obsoleted: 1)
    @objc(profileUpdate:skipTriggers:)
    public func updateProfileFields(
        _ profileFields: NSDictionary? = nil,
        skipTriggers: NSNumber? = nil
    ) {
        self.updateProfileFields(
            profileFields: profileFields as? [String: Any?],
            skipTriggers: skipTriggers?.boolValue
        )
    }
}
