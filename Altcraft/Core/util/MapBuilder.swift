//
//  MapBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Utility for constructing structured dictionaries used in SDK events and request payloads.
@_spi(_Altcraft) public enum MapBuilder {
    /// Key used to store HTTP status code in event payload dictionaries.
    static let httpCodeKey = "http_code"

    /// Merges response/request event and log data with the HTTP status code.
    ///
    /// Preserves Android log order: request fields first, then response
    /// fields (only non-duplicate keys), then `http_code`.
    ///
    /// - Parameters:
    ///   - code: HTTP status code.
    ///   - response: Parsed response data.
    ///   - request: Original request data.
    /// - Returns: Combined event and log payload values.
    static func createEventValue<T: RequestModel.RequestData>(
        code: Int,
        response: T.Response?,
        request: T
    ) -> ResponseModel.ResponseEventValue {
        ResponseModel.ResponseEventValue(
            eventValue: mergedDictionary(
                responseValue: response?.eventData,
                requestValue: request.eventData,
                httpCode: code
            ),
            logValue: ResponseModel.OrderedLogValue(
                orderedMerge(
                    responseValue: response?.logData,
                    requestValue: request.logData,
                    httpCode: code
                )
            )
        )
    }

    /// Merges request + response + http_code into a plain dictionary
    /// (request-first semantics, Android `MapBuilder.kt:63-65`).
    private static func mergedDictionary(
        responseValue: [String: Any?]?,
        requestValue: [String: Any?]?,
        httpCode: Int
    ) -> [String: Any?] {
        (requestValue ?? [:])
            .merging(responseValue ?? [:]) { _, new in new }
            .merging([httpCodeKey: httpCode]) { _, new in new }
    }

    /// Merges request + response + http_code into an ordered entry list,
    /// preserving request-first then response then http_code order
    /// (Android `LinkedHashMap` semantics).
    ///
    /// Within each group keys are sorted alphabetically for determinism
    /// (Swift dictionaries do not preserve insertion order).
    private static func orderedMerge(
        responseValue: [String: Any?]?,
        requestValue: [String: Any?]?,
        httpCode: Int
    ) -> [(key: String, value: Any?)] {
        var seen = Set<String>()
        var result: [(key: String, value: Any?)] = []

        for (key, value) in (requestValue ?? [:]).sorted(by: { $0.key < $1.key }) {
            result.append((key: key, value: value))
            seen.insert(key)
        }

        for (key, value) in (responseValue ?? [:]).sorted(by: { $0.key < $1.key }) {
            if !seen.contains(key) {
                result.append((key: key, value: value))
                seen.insert(key)
            }
        }

        if !seen.contains(httpCodeKey) {
            result.append((key: httpCodeKey, value: httpCode))
        }

        return result
    }

    /// Merges device, app, and custom fields into a single dictionary.
    ///
    /// Matching Android `MapBuilder.unionMaps`: device fields first, then
    /// user-defined custom fields (overriding device on key conflict), then
    /// application metadata (`_app_id`, `_app_iid`, `_app_ver`) last (highest
    /// precedence). Device and AppInfo are resolved internally through
    /// `Environment` — callers only pass user-defined fields.
    ///
    /// If the SDK configuration is missing, the AppInfo contribution is
    /// silently dropped (device + customFields are still merged).
    ///
    /// - Parameter customFields: Optional user-defined custom fields.
    /// - Returns: Combined payload dictionary.
    public static func unionMaps(
        _ customFields: [String: Any]?
    ) async -> [String: Any] {
        let env = Environment.create()
        var result = await env.deviceFields()
        result.merge(customFields ?? [:]) { _, new in new }
        let appInfo = (try? await env.config().appInfo) ?? nil
        result.merge(appInfo?.toAppFieldsMap() ?? [:]) { _, new in new }
        return result
    }
}
