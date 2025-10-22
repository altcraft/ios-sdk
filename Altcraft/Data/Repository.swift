//
//  Repository.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Retrieves common data required for the subscription process.
///
/// This function gathers all necessary components to construct a `CommonData` object:
/// - Fetches the current configuration.
/// - Retrieves the stored device token.
/// - Obtains the authorization header and matching mode based on the configuration token.
///
/// If any of the required elements are missing, the function logs an error and returns `nil` via the completion handler.
///
/// - Parameter completion: A closure that receives a `CommonData` object if all data is available, or `nil` otherwise.
func getCommonData(completion: @escaping (CommonData?) -> Void) {
    let userDefault = StoredVariablesManager.shared
    let tokenManager = TokenManager.shared
    getConfig { config in
        
        tokenManager.getCurrentToken{ currentToken in
            guard let config = config else {
                errorEvent(#function, error: configIsNil)
                completion(nil)
                return
            }
            
            guard let authData = getAuthData(rToken: config.rToken) else {
                errorEvent(#function, error: authDataIsNil)
                completion(nil)
                return
            }

            let savedToken = userDefault.getSavedToken()

            completion(CommonData(
                config: config,
                currentToken: currentToken,
                savedToken:  savedToken,
                authHeader: authData.0,
                matchingMode: authData.1)
            )
        }
    }
}

/// Builds `SubscribeRequestData` using entity details and SDK configuration.
/// Safely materializes the `SubscribeEntity` by its `NSManagedObjectID` inside the given context.
///
/// - Parameters:
///   - context: The `NSManagedObjectContext` used to materialize and read the entity.
///   - entityID: The `NSManagedObjectID` of the `SubscribeEntity`.
///   - completion: Closure returning a valid `SubscribeRequestData` or `nil`.
func getSubscribeRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID,
    completion: @escaping (SubscribeRequestData?) -> Void
) {
    getCommonData { data in
        guard let data = data else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }
        guard let currentToken = data.currentToken else {
            errorEvent(#function, error: currentTokenIsNil)
            completion(nil)
            return
        }
        
        context.perform {
            guard let entity = try? context.existingObject(
                with: objectID
            ) as? SubscribeEntity else {
                errorEvent(#function, error: entityNotFoundByID)
                completion(nil)
                return
            }
            
            let profileFields = decodeAnyMap(entity.profileFields)
            let customFields  = getFields(config: data.config, entity: entity)
            
            let requestData = SubscribeRequestData(
                url: subscribeURL(data.config.url),
                time: entity.time / 1000,
                rToken: data.config.rToken,
                requestId: entity.uid ?? "",
                authHeader: data.authHeader,
                matchingMode: data.matchingMode,
                provider: currentToken.provider,
                deviceToken: currentToken.token,
                status: entity.status ?? "",
                sync: entity.sync,
                profileFields: profileFields,
                customFields: customFields,
                cats: decodeCats(entity.cats),
                replace: entity.replace,
                skipTriggers: entity.skipTriggers
            )
            
            if requestData.isValid() {
                completion(requestData)
            } else {
                errorEvent(#function, error: invalidSubscribeRequestData)
                completion(nil)
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
    getCommonData { data in
        guard let data = data else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }

        context.perform {
            guard let entity = try? context.existingObject(
                with: objectID
            ) as? MobileEventEntity else {
                errorEvent(#function, error: entityNotFoundByID)
                completion(nil)
                return
            }
            
            guard let sid = entity.sid, let name = entity.eventName else {
                errorEvent(#function, error: mobileRequestDataIsNil)
                completion(nil)
                return
            }
            
            let parts = PartsFactory.createMobileEventParts(from: entity)

            // Build request data
            let requestData = MobileEventRequestData(
                url: eventMobileURL(data.config.url),
                sid: sid,
                eventName: name,
                parst: parts,
                authHeader: data.authHeader
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
    getCommonData { data in
        guard let data = data else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }

        context.perform {
            guard let entity = try? context.existingObject(
                with: objectID
            ) as? PushEventEntity else {
                errorEvent(#function, error: entityNotFoundByID)
                completion(nil)
                return
            }
 
            guard let uid = entity.uid,
                  let type = entity.type
            else {
                errorEvent(#function, error: invalidPushEventRequestData)
                completion(nil)
                return
            }

            let requestData = PushEventRequestData(
                url: eventPushURL(data.config.url, event: entity),
                time: entity.time / 1000,
                type: type,
                uid: uid,
                authHeader: data.authHeader,
                matchingMode: data.matchingMode
            )

            if requestData.isValid() {
                completion(requestData)
            } else {
                errorEvent(#function, error: invalidPushEventRequestData)
                completion(nil)
            }
        }
    }
}

/// Builds `UpdateRequestData` for updating the device token.
///
/// Retrieves saved token and SDK configuration. Returns `nil` if required data is missing.
///
/// - Parameter completion: Closure returning a valid `UpdateRequestData` or `nil`.
func getUpdateRequestData(completion: @escaping (UpdateRequestData?) -> Void) {
    getCommonData { data in
        guard let data = data else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }
        
        guard let currentToken = data.currentToken else {
            errorEvent(#function, error: currentTokenIsNil)
            completion(nil)
            return
        }
        
        completion(
            UpdateRequestData(
                url: updateUrl(data.config.url),
                requestId: UUID().uuidString,
                authHeader: data.authHeader,
                oldToken: data.savedToken?.token,
                newToken: currentToken.token,
                oldProvider: data.savedToken?.provider,
                newProvider: currentToken.provider
                
            )
        )
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
    getCommonData { commonData in
        guard let data = commonData else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }
        
        guard let currentToken = data.currentToken else {
            errorEvent(#function, error: currentTokenIsNil)
            completion(nil)
            return
        }
        
    
        let requestData = UnSuspendRequestData(
            url: unSuspendUrl(data.config.url),
            uid: UUID().uuidString,
            provider: currentToken.provider,
            token: currentToken.token,
            authHeader: data.authHeader,
            matchingMode: data.matchingMode
        )

        completion(requestData)
    }
}

/// Builds `ProfileRequestData` used for profile matching.
///
/// Retrieves configuration, saved token, and authentication headers.
/// Returns `nil` via the completion handler if any required data is missing.
///
/// - Parameter completion: Closure returning a valid `ProfileRequestData` or `nil`.
func getProfileRequestData(completion: @escaping (ProfileRequestData?) -> Void) {
    
    getCommonData { data in
        guard let data = data else {
            errorEvent(#function, error: commonDataIsNil)
            completion(nil)
            return
        }
        
        let tokenData = getToken(data: data)
        
        let requestData = ProfileRequestData(
            url: profileUrl(data.config.url),
            uid: UUID().uuidString,
            authHeader: data.authHeader,
            matchingMode: data.matchingMode,
            provider: tokenData?.provider,
            token: tokenData?.token
        )
        
        completion(requestData)
    }
    
    /// Retrieves the preferred token to use for API requests.
    ///
    /// - Parameters:
    ///   - configRToken: Optional value indicating whether a remote token (`rToken`) is provided.
    ///   - currentToken: The current device token fallback if saved one is not available.
    /// - Returns: A `TokenData` object if available; otherwise `nil`.
    func getToken(data: CommonData) -> TokenData? {
        if data.config.rToken != nil {
            return data.savedToken ?? data.currentToken
        } else {
            return data.savedToken
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
