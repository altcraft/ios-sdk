//
//  JsonFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Creates a JSON body for the subscription request.
///
/// - Parameter data: The `SubscribeRequestData` containing subscription details.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createSubscribeJSONBody(data: PushSubscribeRequestData) -> Data? {
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

/// Creates a JSON body for the push token update request.
///
/// - Parameter data: The `UpdateRequestData` containing token details.
/// - Returns: JSON-encoded `Data`, or `nil` if encoding fails.
func createUpdateJSONBody(data: TokenUpdateRequestData) -> Data? {
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

/// Creates a JSON body for the unSuspend request.
///
/// - Parameter data: The `UnSuspendRequestData` containing subscription identifiers.
/// - Returns: JSON-encoded `Data`, or `nil` on failure.
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

/// Creates a JSON body for a push event request.
///
/// - Parameter data: The `PushEventRequestData` containing event time and UID.
/// - Returns: JSON-encoded `Data`, or `nil` if encoding fails.
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


/// Creates a JSON body for the profile update request.
///
/// - Parameter data: The `ProfileUpdateRequestData` containing profile fields and options.
/// - Returns: JSON-encoded `Data`, or `nil` if serialization fails.
func createProfileUpdateJSONBody(data: ProfileUpdateRequestData) -> Data? {
    let keys = Constants.JSONKeys.self

    let json: [String: Any] = [
        keys.profileFields: data.profileFields ?? NSNull(),
        keys.skipTriggers: data.skipTriggers ?? false
    ]

    do {
        return try JSONSerialization.data(withJSONObject: json, options: [])
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}
