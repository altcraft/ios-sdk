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

//?????????
@inline(__always)
private func buildMultipartRequest(
    url: URL,
    parts: [Part],
    authHeader: String
) -> URLRequest {
    var request = URLRequest(url: url)
    request.httpMethod = Constants.HTTPMethod.post

    let boundary = makeBoundary()
    let body = buildMultipartBody(parts: parts, boundary: boundary)
    request.httpBody = body

    // Headers
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: Constants.HTTPHeader.contentType)
    request.setValue(authHeader, forHTTPHeaderField: Constants.HTTPHeader.authorization)
    // По желанию можно указать длину:
    request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")

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
    sync: Int16? = nil,
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
    data: SubscribeRequestData,
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
    
    return buildPostRequest(url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId)
}

/// Creates a URL request for updating a push subscription token.
///
/// - Parameters:
///   - data: The `UpdateRequestData` object containing the request parameters.
///   - requestBody: The JSON-encoded request body.
/// - Returns: An optional `URLRequest` object configured for the update request.
func createUpdateRequest(
    data: UpdateRequestData,
    requestBody: Data
) -> URLRequest? {
    
    guard let url = buildURLComponents(
        url: data.url,
        provider: data.newProvider,
        subscriptionId: data.oldToken
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildPostRequest(url: url, body: requestBody, authHeader: data.authHeader, requestId: data.requestId)
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
    
    return buildPostRequest(url: url, body: requestBody, authHeader: data.authHeader, requestId: data.uid)
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
    
    return buildPostRequest(url: url, body: requestBody, authHeader: data.authHeader, requestId: data.uid)
}

/// Creates a URL request for profile resolution based on saved token and matching rules.
///
/// - Parameter data: The `ProfileRequestData` containing URL, headers, and optional parameters.
/// - Returns: An optional `URLRequest` for the profile request, or `nil` if URL construction fails.
func createProfileRequest(data: ProfileRequestData) -> URLRequest? {
    
    guard let url = buildURLComponents(
        url: data.url,
        provider: data.provider,
        matchingMode: data.matchingMode,
        subscriptionId: data.token
    )?.url else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: data.url])
        return nil
    }
    
    return buildGetRequest( url: url, authHeader: data.authHeader, requestId: data.uid)
}

/// Creates a complete URL request for a push subscription.
///
/// Encodes the request body and builds a `URLRequest` with headers and query parameters.
///
/// - Parameter data: The `SubscribeRequestData` containing subscription parameters.
/// - Returns: A configured `URLRequest`, or `nil` if encoding fails.
func subscribeRequest(data: SubscribeRequestData) -> URLRequest? {
    guard let requestBody = createSubscribeJSONBody(data: data) else {
        return nil
    }
    return createSubscribeRequest(data: data, requestBody: requestBody)
}

/// Creates a complete URL request for updating a push token.
///
/// Encodes the update payload and builds a `URLRequest` with headers and query parameters.
///
/// - Parameter data: The `UpdateRequestData` containing token update info.
/// - Returns: A configured `URLRequest`, or `nil` if encoding fails.
func updateRequest(data: UpdateRequestData) -> URLRequest? {
    guard let requestBody = createUpdateJSONBody(data: data) else {
        return nil
    }
    return createUpdateRequest(data: data, requestBody: requestBody)
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
    provider: String? = nil,
    completion: @escaping (URLRequest?) -> Void
) {
    getProfileRequestData { data in
        guard var data = data else {
            errorEvent(#function, error: profileRequestDataIsNil)
            completion(nil)
            return
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
            completion(nil)
            return
        }

        guard let request = createProfileRequest(data: data) else {
            errorEvent(#function, error: failedCreateRequest)
            completion(nil)
            return
        }

        completion(request)
    }
}


func createMobileEventMultipartRequest(
    baseURLString: String,
    sid: String,
    parts: [Part],
    authHeader: String
) -> URLRequest? {
    guard let url = buildMobileEventURL(
        baseURLString: baseURLString,
        sid: sid,
        tracker: "px",
        type: "open",
        version: "2"
    ) else {
        errorEvent(#function, error: invalidRequestUrl, value: [Constants.MapKeys.url: baseURLString])
        return nil
    }
    return buildMultipartRequest(url: url, parts: parts, authHeader: authHeader)
}
