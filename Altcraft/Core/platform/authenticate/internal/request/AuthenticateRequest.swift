//
//  AuthenticateRequest.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Creates a complete URL request for authorization.
///
/// - Parameter data: The `AuthRequestData` containing authorization parameters.
/// - Returns: A configured `URLRequest`, or `nil` if request construction fails.
func authRequest(
    data: RequestModel.AuthRequestData
) -> URLRequest? {
    guard let requestBody = createAuthJSONBody(
        data: data
    ) else {
        return nil
    }

    guard let url = buildURLComponents(url: data.url)?.url else {
        CoreLog.error(
            #function,
            error: CoreEvents.invalidRequestUrl,
            eventValue: [Constants.MapKeys.url: data.url]
        )
        return nil
    }

    return buildPostRequest(
        url: url,
        body: requestBody,
        authHeader: data.authHeader,
        requestId: data.requestId
    )
}
