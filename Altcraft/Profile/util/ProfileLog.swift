//
//  ProfileLog.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
@_spi(_Altcraft) import AltcraftCore

/// Profile-module facade over the SDK event free functions.
///
/// Prefixes every event, error and retry emitted by the profile module with the
/// module tag and delegates to the `event`/`errorEvent`/`retryEvent` free
/// functions, which remain the single sink for logging and subscriber dispatch.
enum ProfileLog {

    /// Module tag added before the function name in the log line.
    static let MODULE_PREFIX = "[altcraft-profile] "

    /// Emits an SDK event with the profile-module tag.
    @discardableResult
    static func event(
        _ function: String,
        event ev: any SDKEvent,
        eventValue: [String: Any?]? = nil,
        logValue: ResponseModel.OrderedLogValue? = nil
    ) -> Event {
        emitEvent("\(MODULE_PREFIX)\(function)", event: ev, eventValue: eventValue, logValue: logValue)
    }

    /// Emits a non-retryable error with the profile-module tag.
    @discardableResult
    static func error(
        _ function: String,
        error: Any?,
        eventValue: [String: Any?]? = nil,
        logValue: ResponseModel.OrderedLogValue? = nil
    ) -> ErrorEvent {
        errorEvent("\(MODULE_PREFIX)\(function)", error: error, eventValue: eventValue, logValue: logValue)
    }

    /// Emits a retryable error with the profile-module tag.
    @discardableResult
    static func retry(
        _ function: String,
        error: Any?,
        eventValue: [String: Any?]? = nil,
        logValue: ResponseModel.OrderedLogValue? = nil
    ) -> RetryEvent {
        retryEvent("\(MODULE_PREFIX)\(function)", error: error, eventValue: eventValue, logValue: logValue)
    }
}
