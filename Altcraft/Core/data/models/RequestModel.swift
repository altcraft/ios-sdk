//
//  RequestModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Container for the SDK request payload scheme.
///
/// Only the common network contract lives in Core; each module defines its own
/// `RequestData` implementations in its `platform/<feature>/request/` folder.
@_spi(_Altcraft) public enum RequestModel {
    /// Common contract for all network request payload models used in the SDK.
    ///
    /// Each implementation provides a stable request name, SDK events for
    /// success and failure, a response model type, optional event payload data,
    /// and optional log payload data.
    public protocol RequestData {
        associatedtype Response: ResponseModel.ResponseData & Decodable

        /// Stable request identifier.
        var requestName: String { get }

        /// Event emitted when request is completed successfully.
        var successEvent: any SDKEvent { get }

        /// Event emitted when request is completed with failure.
        var failedEvent: any SDKEvent { get }

        /// Response model type used to decode server response.
        var responseType: Response.Type { get }

        /// Optional additional data used as SDK event value payload.
        var eventData: [String: Any?]? { get }

        /// Optional additional data used as SDK log payload.
        var logData: [String: Any?]? { get }

        /// Module log prefix used to tag network response events (e.g. `"[altcraft-inapp] "`).
        ///
        /// Mirrors Android `RequestData.moduleLogPrefix`. The Core
        /// `RequestManager.eventGeneration` prepends this prefix to the
        /// `processResponse` function name so that network responses are tagged
        /// with the module that issued the request.
        var moduleLogPrefix: String { get }
    }
}
