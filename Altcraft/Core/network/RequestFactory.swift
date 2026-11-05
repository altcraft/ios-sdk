//
//  RequestFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Builds a standard `POST` URLRequest with common headers and JSON body.
///
/// - Parameters:
///   - url: The final request URL.
///   - body: The JSON-encoded request body.
///   - authHeader: The authorization token.
///   - requestId: The unique request identifier.
/// - Returns: A configured `URLRequest` object.
func buildPostRequest(url: URL, body: Data, authHeader: String, requestId: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = Constants.HTTPMethod.post
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)
    request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
    request.setValue(requestId, forHTTPHeaderField: Constants.HTTPHeader.requestId)

    return request
}

/// Builds a standard `GET` URLRequest with common headers.
///
/// - Parameters:
///   - url: The final request URL.
///   - authHeader: The authorization token.
///   - requestId: The unique request identifier.
/// - Returns: A configured `URLRequest` object.
func buildGetRequest(url: URL, authHeader: String, requestId: String) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = Constants.HTTPMethod.get
    request.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)
    request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
    request.setValue(requestId, forHTTPHeaderField: Constants.HTTPHeader.requestId)

    return request
}

/// Constructs `URLComponents` with optional query parameters for API requests.
///
/// - Parameters:
///   - url: The base URL string.
///   - provider: Optional provider value.
///   - matchingMode: Optional matching mode.
///   - sync: Optional sync value.
///   - subscriptionId: Optional subscription ID.
/// - Returns: A configured `URLComponents` or `nil` if URL is invalid.
func buildURLComponents(
    url: String,
    provider: String? = nil,
    matchingMode: String? = nil,
    sync: Bool? = nil,
    subscriptionId: String? = nil
) -> URLComponents? {
    guard let baseURL = URL(string: url),
          let scheme = baseURL.scheme, (
            scheme == Constants.URLScheme.http ||
            scheme == Constants.URLScheme.https
          ),
          let host = baseURL.host, !host.isEmpty
    else {
        CoreLog.error(
            #function,
            error: CoreEvents.invalidRequestUrl,
            eventValue: [Constants.MapKeys.url: url]
        )
        return nil
    }

    var comps = URLComponents(
        url: baseURL,
        resolvingAgainstBaseURL: false
    )
    let Q = Constants.QueryItem.self

    let extra: [URLQueryItem] = [
        (Q.provider, provider),
        (Q.matchingMode, matchingMode),
        (Q.sync, sync.map { $0 ? "1" : "0" }),
        (Q.subscriptionId, subscriptionId)
    ].compactMap { name, value in
        guard let value = value else { return nil }
        return URLQueryItem(name: name, value: value)
    }

    if comps?.queryItems?.isEmpty == false {
        comps?.queryItems?.append(contentsOf: extra)
    } else {
        comps?.queryItems = extra
    }

    return comps
}
