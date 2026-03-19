//
//  RequestFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

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

/// Constructs a multipart/form-data `POST` request with the given body parts and auth header.
/// The function sets HTTP method, body, boundary-based Content-Type, Authorization, and Content-Length.
///
/// - Parameters:
///   - url: Final endpoint URL.
///   - parts: Multipart body parts (files/fields) to encode.
///   - authHeader: Value for the `Authorization` HTTP header.
/// - Returns: Fully configured `URLRequest` ready to be sent.
@inline(__always)
private func buildMultipartRequest(
    url: URL,
    parts: [Part],
    authHeader: String,
    requestId: String
) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = Constants.HTTPMethod.post

    let boundary = makeBoundary()
    let body = buildMultipartBody(parts: parts, boundary: boundary)
    request.httpBody = body

    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: Constants.HTTPHeader.contentType)
    request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
    request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
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
        errorEvent(
            #function,
            error: (571, "Invalid URL: \(url)"),
            value: [Constants.MapKeys.url: url]
        )
        return nil
    }
    
    var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    let Q = Constants.QueryItem.self
    
    let extra: [URLQueryItem] = [
        (Q.provider, provider),
        (Q.matchingMode, matchingMode),
        (Q.sync, sync.map(String.init)),
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

/// Builds the final URL for mobile event registration.
///
/// Appends required query parameters according to the web-event spec:
/// - `i`: Pixel ID (SID)
/// - `tr`: Tracker (usually `"px"`)
/// - `t`: Event type (usually `"open"`)
/// - `v`: Protocol version (usually `"2"`)
///
/// - Returns: A valid `URL` with appended query items, or `nil` if the base URL is invalid.
func buildMobileEventURL(
    baseURLString: String,
    sid: String,
    tracker: String,
    type: String,
    version: String
) -> URL? {
    guard var comps = URLComponents(string: baseURLString),
          let scheme = comps.scheme,
          scheme == Constants.URLScheme.http ||
          scheme == Constants.URLScheme.https,
          let host = comps.host, !host.isEmpty
    else {
        return nil
    }

    var items = comps.queryItems ?? []
    items.append(contentsOf: [
        URLQueryItem(name: "i",  value: sid),
        URLQueryItem(name: "tr", value: tracker),
        URLQueryItem(name: "t",  value: type),
        URLQueryItem(name: "v",  value: version),
    ])
    comps.queryItems = items
    return comps.url
}

/// Creates a URL request for a push notification subscription.
///
/// - Parameters:
///   - data: The `SubscribeRequestData` object containing subscription details.
///   - requestBody: The JSON-encoded request body.
/// - Returns: An optional `URLRequest` representing the subscription request, or `nil` if an error occurs.
func createSubscribeRequest(
    data: PushSubscribeRequestData,
    requestBody: Data
) -> URLRequest? {

    guard let url = buildURLComponents(
        url: data.url,
        provider: data.provider,
        matchingMode: data.matchingMode,
        sync: data.sync
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildPostRequest(
        url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId
    )
}

/// Creates a URL request for updating a push subscription token.
///
/// - Parameters:
///   - data: The `TokenUpdateRequestData` object containing the request parameters.
///   - requestBody: The JSON-encoded request body.
/// - Returns: An optional `URLRequest` object configured for the update request.
func createTokenUpdateRequest(
    data: TokenUpdateRequestData,
    requestBody: Data
) -> URLRequest? {
    
    guard let url = buildURLComponents(
        url: data.url,
        provider: data.newProvider,
        sync: data.sync,
        subscriptionId: data.oldToken
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildPostRequest(
        url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId
    )
}

/// Creates a URL request for sending a push event (e.g. open or delivery).
///
/// - Parameters:
///   - data: The `PushEventRequestData` containing URL, headers, and parameters.
///   - requestBody: The JSON-encoded request body.
/// - Returns: An optional `URLRequest` for the push event, or `nil` if URL construction fails.
func createPushEventRequest(
    data: PushEventRequestData,
    requestBody: Data
) -> URLRequest? {
    
    guard let url = buildURLComponents(
        url: data.url,
        matchingMode: data.matchingMode
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildPostRequest(
        url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId
    )
}

/// Builds the `URLRequest` for an unSuspend operation.
///
/// - Parameters:
///   - data: `UnSuspendRequestData` containing API details.
///   - requestBody: Encoded JSON body.
/// - Returns: Fully configured `URLRequest` or `nil` on failure.
func createUnSuspendRequest(
    data: UnSuspendRequestData,
    requestBody: Data
) -> URLRequest? {
    guard let url  = buildURLComponents(
        url: data.url,
        provider: data.provider,
        matchingMode: data.matchingMode,
        subscriptionId: data.token
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildPostRequest(
        url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId
    )
}

/// Creates a URL request for profile resolution based on saved token and matching rules.
///
/// - Parameter data: The `ProfileRequestData` containing URL, headers, and optional parameters.
/// - Returns: An optional `URLRequest` for the profile request, or `nil` if URL construction fails.
func createProfileStatusRequest(data: ProfileStatusRequestData) -> URLRequest? {
    guard let url = buildURLComponents(
        url: data.url,
        provider: data.provider,
        matchingMode: data.matchingMode,
        subscriptionId: data.token
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildGetRequest(url: url, authHeader: data.authHeader, requestId: data.requestId)
}

/// Builds a multipart `URLRequest` for sending a mobile event.
/// Resolves the endpoint via `buildMobileEventURL(...)` (adds `i`, `tr`, `t`, `v`)
/// and delegates to `buildMultipartRequest(url:parts:authHeader:)`.
///
/// - Parameter data: `MobileEventRequestData` containing all required fields.
/// - Returns: Configured `URLRequest`, or `nil` if URL construction fails (error is logged).
func createMobileEventRequest(
    data: MobileEventRequestData
) -> URLRequest? {
    guard let url = buildMobileEventURL(
        baseURLString: data.url,
        sid: data.sid,
        tracker: "px",
        type: "open",
        version: "2"
    ) else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    return buildMultipartRequest(
        url: url, parts: data.parts, authHeader: data.authHeader, requestId: data.requestId
    )
}

/// Creates a URL request for updating profile fields.
///
/// - Parameters:
///   - data: The `ProfileUpdateRequestData` containing URL, headers, and payload options.
///   - requestBody: The JSON-encoded request body.
/// - Returns: An optional `URLRequest` for the profile update, or `nil` if URL construction fails.
func createProfileUpdateRequest(
    data: ProfileUpdateRequestData,
    requestBody: Data
) -> URLRequest? {

    guard let url = buildURLComponents(
        url: data.url
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }

    return buildPostRequest(
        url: url,
        body: requestBody,
        authHeader: data.authHeader,
        requestId: data.requestId
    )
}

/// Creates a complete URL request for a push subscription.
///
/// Encodes the request body and builds a `URLRequest` with headers and query parameters.
///
/// - Parameter data: The `SubscribeRequestData` containing subscription parameters.
/// - Returns: A configured `URLRequest`, or `nil` if encoding fails.
func pushSubscribeRequest(data: PushSubscribeRequestData) -> URLRequest? {
    guard let requestBody = createSubscribeJSONBody(data: data) else {
        return nil
    }
    return createSubscribeRequest(data: data, requestBody: requestBody)
}

/// Creates a complete URL request for updating a push token.
///
/// Encodes the update payload and builds a `URLRequest` with headers and query parameters.
///
/// - Parameter data: The `TokenUpdateRequestData` containing token update info.
/// - Returns: A configured `URLRequest`, or `nil` if encoding fails.
func tokenUpdateRequest(data: TokenUpdateRequestData) -> URLRequest? {
    guard let requestBody = createUpdateJSONBody(data: data) else {
        return nil
    }
    return createTokenUpdateRequest(data: data, requestBody: requestBody)
}

/// Creates a complete URL request for sending a push event.
///
/// Encodes the event payload and builds a `URLRequest` with headers and query parameters.
///
/// - Parameter data: The `PushEventRequestData` containing event metadata.
/// - Returns: A configured `URLRequest`, or `nil` if encoding fails.
func pushEventRequest(data: PushEventRequestData) -> URLRequest? {
    guard let requestBody = createPushEventJSONBody(data: data) else {
        return nil
    }
    return createPushEventRequest(data: data, requestBody: requestBody)
}

/// Creates a complete URL request for the unSuspend operation.
///
/// Encodes the unSuspend payload and builds a `URLRequest` with appropriate headers.
///
/// - Parameter data: The `UnSuspendRequestData` object containing request configuration and authentication.
/// - Returns: A configured `URLRequest`, or `nil` if JSON encoding fails.
func unSuspendRequest(data: UnSuspendRequestData) -> URLRequest? {
    guard let body = createUnSuspendJSONBody(data: data) else {
        return nil
    }
    return createUnSuspendRequest(data: data, requestBody: body)
}

/// Creates a complete URL request for updating profile fields.
///
/// Encodes the update payload and builds a `URLRequest` with headers.
///
/// - Parameter data: The `ProfileUpdateRequestData` containing profile update parameters.
/// - Returns: A configured `URLRequest`, or `nil` if JSON encoding fails.
func profileUpdateRequest(data: ProfileUpdateRequestData) -> URLRequest? {
    guard let requestBody = createProfileUpdateJSONBody(data: data) else {
        return nil
    }
    return createProfileUpdateRequest(data: data, requestBody: requestBody)
}

/// Internal helper: builds a `URLRequest` for a subscription status call
/// based on the specified matching mode. All public APIs should call this
/// helper and then send the request themselves.
///
/// - Parameters:
///   - mode: Matching mode (`latest_subscription`, `latest_for_provider`, `match_current_context`).
///   - provider: Optional provider override for `latest_for_provider`.
///   - completion: Closure receiving a built `URLRequest` or `nil` on failure.
func statusRequest(
    mode: String,
    provider: String? = nil
) async -> URLRequest? {
    let data  = await getProfileStatusRequestData()
    guard var data = data else {
        errorEvent(#function, error: profileRequestDataIsNil)
        return nil
    }
    
    switch mode {
    case Constants.StatusMode.matchCurrentContext:
        break
        
    case Constants.StatusMode.latestSubscription:
        data.provider = nil
        data.token = nil
        
    case Constants.StatusMode.latestForProvider:
        data.provider = provider ?? data.provider
        data.token = nil
        
    default:
        return nil
    }
    
     guard let request = createProfileStatusRequest(data: data) else {
        errorEvent(#function, error: failedCreateRequest)
        return  nil
    }
    
    return request
}


