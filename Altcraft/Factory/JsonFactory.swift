//
//  JsonFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/**
 Creates a JSON body for the push notification subscription request.

 - Parameter data: The `SubscribeRequestData` object containing subscription details.
 - Returns: An optional `Data` representing the JSON-encoded request body, or `nil` if serialization fails.
 */
func createSubscribeJSONBody(data: SubscribeRequestData) -> Data? {
    let keys = Constants.JSONKeys.self

    let catsArray: [[String: Any]] = data.cats?.map { cat in
        var dict: [String: Any] = [:]
        if let name = cat.name { dict[keys.catsName] = name }
        if let title = cat.title { dict[keys.catsTitle] = title }
        if let steady = cat.steady { dict[keys.catsSteady] = steady }
        if let active = cat.active { dict[keys.catsActive] = active }
        return dict
    } ?? []

    let subscription: [String: Any] = [
        keys.subscriptionId: data.deviceToken,
        keys.provider: data.provider,
        keys.status: data.status,
        keys.fields: data.customFields,
        keys.cats: catsArray
    ]

    var json: [String: Any] = [
        keys.time: data.time,
        keys.subscriptionId: data.deviceToken,
        keys.subscription: subscription,
        keys.replace: data.replace ?? false,
        keys.skipTriggers: data.skipTriggers ?? false
    ]


    if let profileFields = data.profileFields {
        json[keys.profileFields] = profileFields
    }

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/**
 Creates a JSON payload for updating a device token.

 - Parameter data: The `UpdateRequestData` object containing old and new token information.
 - Returns: A `Data` object representing the JSON body, or `nil` if encoding fails.
 */
func createUpdateJSONBody(data: UpdateRequestData) -> Data? {
    let keys = Constants.JSONKeys.self

    let json: [String: String?] = [
        keys.oldToken: data.oldToken,
        keys.oldProvider: data.oldProvider,
        keys.newToken: data.newToken,
        keys.newProvider: data.newProvider
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Creates a JSON payload for the unSuspend request.
///
/// - Parameter data: The `UnSuspendRequestData` object containing subscription information.
/// - Returns: A `Data` object representing the JSON body, or `nil` if encoding fails.
func createUnSuspendJSONBody(data: UnSuspendRequestData) -> Data? {
    let keys = Constants.JSONKeys.self
    
    let json: [String: Any] = [
        keys.subscription: [
            keys.subscriptionId: data.token,
            keys.provider: data.provider
        ],
        keys.replace: true
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/**
 Creates a JSON payload for a push event request.

 This function converts the given `PushEventRequestData` into a JSON-compatible
 dictionary and encodes it into `Data` for use as a request body.

 - Parameter data: The request data containing event details such as time and UID.
 - Returns: A `Data` object representing the JSON body, or `nil` if encoding fails.
 */
func createPushEventJSONBody(data: PushEventRequestData) -> Data? {
    let keys = Constants.JSONKeys.self

    let json: [String: Any] = [
        keys.time: data.time,
        keys.smid: data.uid
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}
