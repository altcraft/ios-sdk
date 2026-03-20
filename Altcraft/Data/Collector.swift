//
//  Collector.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Builds `SubscribeRequestData` using entity details and SDK environment.
/// Safely materializes the `SubscribeEntity` by its `NSManagedObjectID` inside the given context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize and read the entity.
///   - objectID: The `NSManagedObjectID` of the `SubscribeEntity`.
/// - Returns: A valid `SubscribeRequestData` or `nil`.
func getSubscribeRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> PushSubscribeRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()
        
        let config = try await env.config()
        let token = try await env.token()
        let auth = try await env.auth()
        
        let entity = try await existingObject(
            context: context,
            objectID: objectID,
            as: SubscribeEntity.self
        )

        let profileFields = decodeAnyMap(entity.profileFields)
        let appFields = config.appInfo?.toAppFieldsMap() ?? [:]
        let cats = decodeCats(entity.cats)
        let customFields = await getFields(
            appFields: appFields,
            customFieldsData: entity.customFields
        )

        let result = PushSubscribeRequestData(
            url: subscribeURL(config.url),
            requestId: entity.requestId ?? "",
            time: entity.time / 1000,
            rToken: config.rToken,
            authHeader: auth.header,
            matchingMode: auth.matching,
            provider: token.provider,
            deviceToken: token.token,
            status: entity.status ?? "",
            sync: entity.sync == 1,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: entity.replace,
            skipTriggers: entity.skipTriggers
        )
        
        guard result.isValid() else {
            errorEvent(#function, error: invalidSubRequestData)
            return nil
        }

        return result
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Builds `MobileEventRequestData` from a `MobileEventEntity` identified by `objectID`.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object.
///   - objectID: The `NSManagedObjectID` of the `MobileEventEntity`.
/// - Returns: A fully built `MobileEventRequestData` or `nil` on failure.
func getMobileEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> MobileEventRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()

        let config = try await env.config()
        let auth = try await env.auth()

        let entity = try await existingObject(
            context: context,
            objectID: objectID,
            as: MobileEventEntity.self
        )

        guard let sid = entity.sid, let name = entity.eventName else {
            errorEvent(#function, error: mobileRequestDataIsNil)
            return nil
        }

        let parts = PartsFactory.createMobileEventParts(from: entity)

        let requestData = MobileEventRequestData(
            url: eventMobileURL(config.url),
            requestId: entity.requestId ?? "",
            sid: sid,
            eventName: name,
            parts: parts,
            authHeader: auth.header
        )

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Builds `ProfileUpdateRequestData` from a `ProfileUpdateEntity` identified by `objectID`.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object and read fields.
///   - objectID: The `NSManagedObjectID` of the `ProfileUpdateEntity`.
/// - Returns: A fully built `ProfileUpdateRequestData` or `nil` on failure.
func getProfileUpdateRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> ProfileUpdateRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()

        let config = try await env.config()
        let auth = try await env.auth()

        let entity = try await existingObject(
            context: context,
            objectID: objectID,
            as: ProfileUpdateEntity.self
        )

        let profileFields = decodeAnyMap(entity.profileFields)

        let requestData = ProfileUpdateRequestData(
            url: profileUpdateURL(config.url),
            requestId: entity.requestId ?? "",
            authHeader: auth.header,
            profileFields: profileFields,
            skipTriggers: entity.skipTriggers
        )

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Builds `PushEventRequestData` from a `PushEventEntity` identified by `objectID`.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object and read fields.
///   - objectID: The `NSManagedObjectID` of the `PushEventEntity`.
/// - Returns: A fully built `PushEventRequestData` or `nil` on failure.
func getPushEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> PushEventRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()
        let config = try await env.config()
        let auth = try await env.auth()
        
        let entity = try await existingObject(
            context: context,
            objectID: objectID,
            as: PushEventEntity.self
        )

        guard let uid = entity.uid,
              let type = entity.type else {
            errorEvent(
                #function,
                error: invalidPushEventRequestData
            )
            return nil
        }

        let requestData = PushEventRequestData(
            url: eventPushURL(config.url, event: entity),
            requestId: entity.requestId ?? "",
            time: entity.time / 1000,
            type: type,
            uid: uid,
            authHeader: auth.header,
            matchingMode: auth.matching
        )

        guard requestData.isValid() else {
            errorEvent(
                #function,
                error: invalidPushEventRequestData
            )
            return nil
        }

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Builds `TokenUpdateRequestData` for updating the device token.
///
/// Retrieves saved token and SDK configuration. Returns `nil` if required data is missing.
///
/// - Returns: A valid `TokenUpdateRequestData` or `nil`.
func getTokenUpdateRequestData() async -> TokenUpdateRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()
        let savedToken = env.savedToken()
        let config = try await env.config()
        let auth = try await env.auth()
        let currentToken = try await env.token()
        
        let requestData = TokenUpdateRequestData(
            url: tokenUpdateUrl(config.url),
            requestId: UUID().uuidString,
            authHeader: auth.header,
            oldToken: savedToken?.token,
            newToken: currentToken.token,
            oldProvider: savedToken?.provider,
            newProvider: currentToken.provider,
            sync: !(config.rToken?.isEmpty ?? true)
        )

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Prepares `UnSuspendRequestData` required for the unSuspend API call.
///
/// This method fetches the common configuration and authentication data,
/// constructs the request body, and returns it.
/// If data is missing or invalid, the error is logged and `nil` is returned.
///
/// - Returns: Optional `UnSuspendRequestData`.
func getUnSuspendRequestData() async -> UnSuspendRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()

        let config = try await env.config()
        let token = try await env.token()
        let auth = try await env.auth()
       
        let requestData = UnSuspendRequestData(
            url: unSuspendUrl(config.url),
            requestId: UUID().uuidString,
            provider: token.provider,
            token: token.token,
            authHeader: auth.header,
            matchingMode: auth.matching
        )

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Builds `ProfileRequestData` used for profile matching.
///
/// Retrieves configuration, saved token, and authentication headers.
/// Returns `nil` if any required data is missing.
///
/// - Returns: A valid `ProfileStatusRequestData` or `nil`.
func getProfileStatusRequestData() async -> ProfileStatusRequestData? {
    let env = Environment.create()

    do {
        try env.checkCoreDataError()
        let savedToken = env.savedToken()
        let config = try await env.config()
        let currentToken = try? await env.token()
        let auth = try await env.auth()
        
        let tokenData = savedToken ?? currentToken

        let requestData = ProfileStatusRequestData(
            url: profileStatusUrl(config.url),
            requestId: UUID().uuidString,
            authHeader: auth.header,
            matchingMode: auth.matching,
            provider: tokenData?.provider,
            token: tokenData?.token
        )

        return requestData
    } catch {
        errorEvent(#function, error: error)
        return nil
    }
}

/// Retrieves and merges device, app, and custom fields for a subscription (iOS 12+).
///
/// - Parameters:
///   - appFields: App fields snapshot (derived from configuration).
///   - customFieldsData: Raw JSON data from entity.customFields (optional).
/// - Returns: Merged fields dictionary.
func getFields(
    appFields: [String: String],
    customFieldsData: Data?
) async -> [String: Any] {
    let deviceFields = await DeviceInfo.getDeviceFields()
    var fields: [String: Any] = deviceFields.asDictionary()

    fields.merge(appFields) { _, new in new }

    if let customFieldsData,
       let obj = try? JSONSerialization.jsonObject(with: customFieldsData),
       let customFields = obj as? [String: Any] {
        fields.merge(customFields) { _, new in new }
    }

    return fields
}
