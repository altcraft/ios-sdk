//
//  TargetModuleEvents.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Events belonging to the target module.
public enum TargetModuleEvents: String, SDKEvent {

    // MARK: - Missing or null request payloads (retryable)

    case mobileRequestDataIsNil = "mobile event request data is nil"

    // MARK: - Successful API requests

    case mobileEventRequestSuccessful = "successful request: event/post"

    // MARK: - Failed API requests

    case mobileEventRequestFailed = "failed request: event/post"

    public var message: String { rawValue }
}
