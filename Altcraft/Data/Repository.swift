//
//  Repository.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Returns configuration data and authentication details (authorization header and matching mode).
///
/// - Parameter completion: A closure receiving `RequestData` or `nil` if retrieval fails.
func getRequestData(completion: @escaping (RequestData?) -> Void) {
    getConfig { config in
        let authData: (String, String)? = if let config {
            getAuthData(rToken: config.rToken)
        } else {
            nil
        }
        completion(RequestData(config: config, auth: authData))
    }
}

/// Builds `SubscribeRequestData` using entity details and SDK configuration.
/// Safely materializes the `SubscribeEntity` by its `NSManagedObjectID` inside the given context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize and read the entity.
///   - objectID: The `NSManagedObjectID` of the `SubscribeEntity`.
///   - completion: Closure returning a valid `SubscribeRequestData` or `nil`.
func getSubscribeRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: @escaping (SubscribeRequestData?) -> Void
) {
    getRequestData { data in
        TokenManager.shared.getCurrentToken { token in
            let fail: ((Int, String)) -> Void = { error in
                errorEvent(#function, error: error)
                completion(nil)
            }

            guard let config = data?.config else { return fail(configIsNil) }
            guard let auth = data?.auth else { return fail(authDataIsNil) }
            guard let token = token else { return fail(pushTokenIsNil) }
            
            context.perform {
                guard let entity = try? context.existingObject(
                    with: objectID
                ) as? SubscribeEntity else {
                    fail(entityNotFoundByID)
                    return
                }
                
                let profileFields = decodeAnyMap(entity.profileFields)
                let customFields  = getFields(config: config, entity: entity)
                
                let requestData = SubscribeRequestData(
                    url: subscribeURL(config.url),
                    time: entity.time / 1000,
                    rToken: config.rToken,
                    requestId: entity.uid ?? "",
                    authHeader: auth.0,
                    matchingMode: auth.1,
                    provider: token.provider,
                    deviceToken: token.token,
                    status: entity.status ?? "",
                    sync: entity.sync,
                    profileFields: profileFields,
                    customFields: customFields,
                    cats: decodeCats(entity.cats),
                    replace: entity.replace,
                    skipTriggers: entity.skipTriggers
                )
                
                guard requestData.isValid() else {
                    fail(invalidSubscribeRequestData)
                    return
                }
                
                completion(requestData)
            }
        }
    }
}

/// Builds `MobileEventRequestData` from a `MobileEventEntity` identified by `objectID`.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object.
///   - objectID: The `NSManagedObjectID` of the `MobileEventEntity`.
///   - completion: Closure returning a fully built `MobileEventRequestData` or `nil` on failure.
///
/// - Notes:
///   - Object materialization and field access happen inside `context.perform {}` to ensure thread safety.
///   - If the materialized object is missing or has a wrong type, it is treated as invalid; the function returns `nil`.
func getMobileEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: @escaping (MobileEventRequestData?) -> Void
) {
    getRequestData { data in
        let fail: ((Int, String)) -> Void = { error in
            errorEvent(#function, error: error)
            completion(nil)
        }

        guard let config = data?.config else { return fail(configIsNil) }
        guard let auth = data?.auth else { return fail(authDataIsNil) }
        
        context.perform {
            guard let entity = try? context.existingObject(
                with: objectID
            ) as? MobileEventEntity else {
                return fail(entityNotFoundByID)
            }
            
            guard let sid = entity.sid,
                  let name = entity.eventName else {
                return fail(mobileRequestDataIsNil)
            }
            
            let parts = PartsFactory.createMobileEventParts(from: entity)
            
            let requestData = MobileEventRequestData(
                url: eventMobileURL(config.url),
                sid: sid,
                eventName: name,
                parts: parts,
                authHeader: auth.0
            )
            
            completion(requestData)
        }
    }
}

/// Builds `PushEventRequestData` from a `PushEventEntity` identified by `objectID`.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize the object and read fields.
///   - objectID: The `NSManagedObjectID` of the `PushEventEntity`.
///   - completion: Closure returning a fully built `PushEventRequestData` or `nil` on failure.
///
/// - Note: Object materialization and field access happen inside `context.perform {}` to ensure thread safety.
func getPushEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: @escaping (PushEventRequestData?) -> Void
) {
    getRequestData { data in
        let fail: ((Int, String)) -> Void = { error in
            errorEvent(#function, error: error)
            completion(nil)
        }

        guard let config = data?.config else { return fail(configIsNil) }
        guard let auth = data?.auth else { return fail(authDataIsNil) }

        context.perform {
            guard let entity = try? context.existingObject(
                with: objectID
            ) as? PushEventEntity else {
                return fail(entityNotFoundByID)
            }

            guard let uid = entity.uid,
                  let type = entity.type else {
                return fail(invalidPushEventRequestData)
            }

            let requestData = PushEventRequestData(
                url: eventPushURL(config.url, event: entity),
                time: entity.time / 1000,
                type: type,
                uid: uid,
                authHeader: auth.0,
                matchingMode: auth.1
            )

            guard requestData.isValid() else {
                return fail(invalidPushEventRequestData)
            }

            completion(requestData)
        }
    }
}

/// Builds `UpdateRequestData` for updating the device token.
///
/// Retrieves saved token and SDK configuration. Returns `nil` if required data is missing.
///
/// - Parameter completion: Closure returning a valid `UpdateRequestData` or `nil`.
func getUpdateRequestData(completion: @escaping (UpdateRequestData?) -> Void) {
    getRequestData { data in
        TokenManager.shared.getCurrentToken { token in
            let fail: ((Int, String)) -> Void = { error in
                errorEvent(#function, error: error)
                completion(nil)
            }

            guard let currentToken = token else { return fail(pushTokenIsNil) }
            guard let config = data?.config else { return fail(configIsNil) }
            guard let auth = data?.auth else { return fail(authDataIsNil) }
            let savedToken = StoredVariablesManager.shared.getSavedToken()
            
            let requestData = UpdateRequestData(
                url: updateUrl(config.url),
                requestId: UUID().uuidString,
                authHeader: auth.0,
                oldToken: savedToken?.token,
                newToken: currentToken.token,
                oldProvider: savedToken?.provider,
                newProvider: currentToken.provider
            )

            completion(requestData)
        }
    }
}

/// Prepares `UnSuspendRequestData` required for the unSuspend API call.
///
/// This method fetches the common configuration and authentication data,
/// constructs the request body, and returns it via completion.
/// If data is missing or invalid, the error is logged and `nil` is returned.
///
/// - Parameter completion: Closure returning optional `UnSuspendRequestData`.
func getUnSuspendRequestData(completion: @escaping (UnSuspendRequestData?) -> Void) {
    getRequestData { data in
        TokenManager.shared.getCurrentToken { token in
            let fail: ((Int, String)) -> Void = { error in
                errorEvent(#function, error: error)
                completion(nil)
            }

            guard let config = data?.config else { return fail(configIsNil) }
            guard let auth = data?.auth else { return fail(authDataIsNil) }
            guard let token = token else { return fail(pushTokenIsNil) }
            
            let requestData = UnSuspendRequestData(
                url: unSuspendUrl(config.url),
                uid: UUID().uuidString,
                provider: token.provider,
                token: token.token,
                authHeader: auth.0,
                matchingMode: auth.1
            )
            
            completion(requestData)
        }
    }
}

/// Builds `ProfileRequestData` used for profile matching.
///
/// Retrieves configuration, saved token, and authentication headers.
/// Returns `nil` via the completion handler if any required data is missing.
///
/// - Parameter completion: Closure returning a valid `ProfileRequestData` or `nil`.
func getProfileRequestData(completion: @escaping (ProfileRequestData?) -> Void) {
    getRequestData { data in
        TokenManager.shared.getCurrentToken { currentToken in
            let fail: ((Int, String)) -> Void = { error in
                errorEvent(#function, error: error)
                completion(nil)
            }

            guard let config = data?.config else { return fail(configIsNil) }
            guard let auth = data?.auth else { return fail(authDataIsNil) }
            let savedToken = StoredVariablesManager.shared.getSavedToken()
            let tokenData = savedToken ?? currentToken
            
            let requestData = ProfileRequestData(
                url: profileUrl(config.url),
                uid: UUID().uuidString,
                authHeader: auth.0,
                matchingMode: auth.1,
                provider: tokenData?.provider,
                token: tokenData?.token
            )
            
            completion(requestData)
        }
    }
}

/// Retrieves and merges device, app, and custom fields for a subscription.
///
/// - Parameters:
///   - config: The `Configuration` object with app-specific info.
///   - entity: The `SubscribeEntity` containing stored custom fields.
/// - Returns: A merged `[String: Any]` dictionary of all available fields.
func getFields(config: Configuration, entity: SubscribeEntity) -> [String: Any] {
    let deviceFields = DeviceInfo.getDeviceFields()
    let appFields: [String: String] = config.appInfo?.toAppFieldsMap() ?? [:]
    
    var fields = deviceFields.merging(appFields) { (_, new) in new }
    
    if let customFieldsData = entity.customFields,
       let customFields = try? JSONSerialization.jsonObject(with: customFieldsData) as? [String: Any] {
        fields.merge(customFields) { (_, new) in new }
    }
    
    return fields
}
