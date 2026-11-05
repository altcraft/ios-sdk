//
//  ProfileModuleEvents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Events belonging to the profile module.
public enum ProfileModuleEvents: String, SDKEvent {

    // MARK: - Missing or null request payloads (retryable)

    case profileUpdateRequestDataIsNil = "profile update request data is nil"

    // MARK: - Successful API requests

    case profileUpdateRequestSuccessful = "successful request: profile/update"

    // MARK: - Failed API requests

    case profileUpdateRequestFailed = "failed request: profile/update"

    public var message: String { rawValue }
}
