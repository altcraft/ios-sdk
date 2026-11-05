//
//  EventList.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Base contract for all SDK events emitted by the platform.
///
/// Core defines the generic events in ``CoreEvents``; each module declares its
/// own event enum (e.g. ``PushModuleEvents``, ``InAppModuleEvents``,
/// ``ProfileModuleEvents``, ``TargetModuleEvents``) that conforms to this protocol.
public protocol SDKEvent: Sendable, Equatable {

    /// Message describing the event.
    var message: String { get }
}

// MARK: - Core events

/// General and platform-level SDK events that belong to the core module.
public enum CoreEvents: String, SDKEvent {

    // MARK: - General SDK events

    case configSet = "SDK configuration is installed."
    case sdkCleared = "SDK data has been cleared"
    case rTokenChange = "Role token change: SDK database data will be cleared, except for configuration data."
    case initAwait = "waiting for SDK initialization to complete"
    case userLogOut = "User logged out. Anonymous session started"
    case backgroundTaskRegister = "SDK background task is registered"
    case backgroundTaskCompleted = "SDK background task completed"

    // MARK: - Internal non-retryable errors

    case configIsNotSet = "the configuration is not set"
    case coreDataError = "error in CoreData. Re-initialize the SDK."
    case errorLoadModelInCoreData = "failed to load model from framework."
    case appGroupIsNotSet = "App Group name was not set."
    case contextIsUnavailable = "core data context is unavailable"
    case invalidCoreDataEntityName = "the coreData entity name is not valid"
    case entityNotFoundByID = "entity not found by ID"
    case coreDataModelNotFoundInBundle = "Core Data model was not found in any bundle"
    case coreDataModelMissingEntity = "Core Data model is missing the required entity; the model did not load"
    case sdkInitWaitingExpired = "SDK initialization timeout has expired"
    case notAuthenticatedError = "user is not authenticated"

    // MARK: - Invalid values

    case invalidUrlValue = "invalid apiUrl value - empty or null."
    case invalidRTokenValue = "invalid resource token value - resource token is empty."
    case nonJsonObject = "non-json object has been provided"
    case fieldsIsObjects = "invalid values: not all values are primitives"

    // MARK: - Missing SDK state or environment issues

    case configIsNil = "config data is nil"
    case userTagIsNil = "userTag is null. It is impossible to identify the user"
    case permissionDenied = "notification permission denied."
    case backgroundTaskExpired = "SDK background task expired"

    // MARK: - Authorization-related errors

    case jwtIsNil = "JWT token is nil"
    case jwtParsingError = "JWT parsing error"
    case externalAuthDataIsNil = "external auth data is nil"
    case internalAuthDataIsNil = "internal auth data is nil"

    // MARK: - Request / response errors

    case failedCreateRequest = "Failed to create request."
    case failedProcessingResponse = "Failed processing the response"

    // MARK: - Invalid request / response values

    case responseDataIsNull = "response data is null"
    case invalidRequestUrl = "invalid request url"
    case invalidResponseFormat = "invalid response format"

    // MARK: - Successful API requests

    case authenticateSuccessful = "successful request: profile/authenticate"

    // MARK: - Failed API requests

    case authenticateFailed = "failed request: profile/authenticate"

    public var message: String { rawValue }
}
