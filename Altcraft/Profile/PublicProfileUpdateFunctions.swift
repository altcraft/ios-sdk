//
//  PublicProfileFunctions.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Public API for updating Altcraft profile fields.
@objcMembers
public final class PublicProfileFunctions: NSObject, @unchecked Sendable {

    public static let shared = PublicProfileFunctions()

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
            errorEvent(#function, error: fieldsIsObjects)
            return
        }

        let profileFieldsData = encodeAnyMap(profileFields)

        ProfileUpdateQueues.entityQueue.submit {
            await ProfileUpdate.shared.updateProfileFields(
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
