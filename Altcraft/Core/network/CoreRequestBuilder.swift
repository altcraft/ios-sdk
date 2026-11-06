//
//  CoreRequestBuilder.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
/// Builds URL requests for SDK modules without leaking Core configuration or
/// authorization data into module code.
///
/// The base URL and the `Authorization` header are resolved internally from the
/// Core environment (configuration + auth data) every time a request is built.
/// Modules provide only a relative `path`, an optional request body, optional
/// query items, and the request identifier.
@_spi(_Altcraft) public enum CoreRequestBuilder {
    /// Builds a standard `POST` URLRequest with JSON content type.
    public static func post(
        path: String,
        body: Data?,
        queryItems: [URLQueryItem]? = nil,
        requestId: String,
        includeMatchingMode: Bool = false
    ) async -> URLRequest? {
        guard let (url, authHeader) = await resolve(
            path: path,
            queryItems: queryItems,
            includeMatchingMode: includeMatchingMode
        ) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = Constants.HTTPMethod.post
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)
        request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
        request.setValue(requestId, forHTTPHeaderField: Constants.HTTPHeader.requestId)
        return request
    }

    /// Builds a standard `GET` URLRequest with common headers.
    public static func get(
        path: String,
        queryItems: [URLQueryItem]? = nil,
        requestId: String,
        includeMatchingMode: Bool = false
    ) async -> URLRequest? {
        guard let (url, authHeader) = await resolve(
            path: path,
            queryItems: queryItems,
            includeMatchingMode: includeMatchingMode
        ) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = Constants.HTTPMethod.get
        request.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)
        request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
        request.setValue(requestId, forHTTPHeaderField: Constants.HTTPHeader.requestId)
        return request
    }

    /// Builds a multipart/form-data `POST` URLRequest with an explicit
    /// `Content-Length` header (used by the mobile event endpoint).
    public static func multipartPost(
        path: String,
        body: Data,
        boundary: String,
        queryItems: [URLQueryItem]? = nil,
        requestId: String,
        includeMatchingMode: Bool = false
    ) async -> URLRequest? {
        guard let (url, authHeader) = await resolve(
            path: path,
            queryItems: queryItems,
            includeMatchingMode: includeMatchingMode
        ) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = Constants.HTTPMethod.post
        request.httpBody = body
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: Constants.HTTPHeader.contentType
        )
        request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
        request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        request.setValue(requestId, forHTTPHeaderField: Constants.HTTPHeader.requestId)
        return request
    }

    /// Downloads a public static resource (JS/CSS) relative to the API URL.
    ///
    /// Resolves the base URL from the Core environment and fetches the body
    /// without authorization headers, mirroring the Android `getRawText`
    /// helper used for public in-app static files.
    ///
    /// - Parameter path: Relative static resource path.
    /// - Returns: UTF-8 decoded text body, or `nil` if resolution or
    ///   downloading fails.
    public static func getRawText(path: String) async -> String? {
        guard let comps = await buildURLComponents(path: path, queryItems: nil),
              let url = comps.url else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8)
        } catch {
            CoreLog.error(#function, error: error)
            return nil
        }
    }

    /// Resolves the full request URL and the authorization header for a module
    /// request from the Core environment.
    ///
    /// - Parameters:
    ///   - path: Relative API path.
    ///   - queryItems: Module-provided query items.
    ///   - includeMatchingMode: Whether the matching mode (derived from auth
    ///     data) should be appended as a `matchingMode` query item.
    /// - Returns: Resolved URL and authorization header, or `nil` on failure.
    private static func resolve(
        path: String,
        queryItems: [URLQueryItem]?,
        includeMatchingMode: Bool
    ) async -> (URL, String)? {
        guard let comps = await buildURLComponents(
            path: path,
            queryItems: queryItems
        ) else {
            return nil
        }

        guard let config = try? await Environment.create().config(),
              let auth = await getAuthData(rToken: config.rToken) else {
            CoreLog.error(
                #function,
                error: CoreEvents.externalAuthDataIsNil,
                eventValue: [Constants.MapKeys.url: path]
            )
            return nil
        }

        var resolved = comps
        if includeMatchingMode, !auth.1.isEmpty {
            var items = resolved.queryItems ?? []
            items.append(
                URLQueryItem(
                    name: Constants.QueryItem.matchingMode,
                    value: auth.1
                )
            )
            resolved.queryItems = items
        }

        guard let url = resolved.url else {
            CoreLog.error(
                #function,
                error: CoreEvents.invalidRequestUrl,
                eventValue: [Constants.MapKeys.url: path]
            )
            return nil
        }

        return (url, auth.0)
    }

    /// Builds URL components for a relative API path against the configured
    /// API URL, checking Core Data health and URL validity.
    ///
    /// Only the **Core module's** critical flag gates request building:
    /// Core Data holds the configuration and authentication data every
    /// request needs. A critical error in another module's store does not
    /// block the network layer — that module's operations fail on their own
    /// isolated flag. The Core flag is recoverable: it is cleared on the
    /// next successful Core Data store load.
    ///
    /// - Parameters:
    ///   - path: Relative API path.
    ///   - queryItems: Optional query items to append.
    /// - Returns: Validated `URLComponents`, or `nil` on failure.
    private static func buildURLComponents(
        path: String,
        queryItems: [URLQueryItem]?
    ) async -> URLComponents? {
        if StoredVariablesManager.shared.getDbErrorStatus() {
            CoreLog.error(#function, error: CoreEvents.coreDataError)
            return nil
        }

        guard let config = try? await Environment.create().config() else {
            CoreLog.error(
                #function,
                error: CoreEvents.invalidRequestUrl,
                eventValue: [Constants.MapKeys.url: path]
            )
            return nil
        }
        let apiUrl = config.apiUrl

        guard var comps = URLComponents(string: apiUrl + path),
              let scheme = comps.scheme, (
                scheme == Constants.URLScheme.http ||
                scheme == Constants.URLScheme.https
              ),
              let host = comps.host, !host.isEmpty else {
            CoreLog.error(
                #function,
                error: CoreEvents.invalidRequestUrl,
                eventValue: [Constants.MapKeys.url: apiUrl + path]
            )
            return nil
        }

        if let queryItems, !queryItems.isEmpty {
            comps.queryItems = (comps.queryItems ?? []) + queryItems
        }

        return comps
    }
}
