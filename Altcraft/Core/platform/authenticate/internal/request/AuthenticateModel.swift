//
//  AuthenticateModel.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Builds the authentication request payload.
///
/// Mirrors Android `AuthenticateRequestModel`: all request data for the
/// `authenticate` feature is assembled on the request model from the stored
/// auth request entity.
enum AuthenticateModel {

    /// Builds `AuthRequestData` from an `AuthRequestEntity` identified
    /// by its object identifier.
    ///
    /// - Parameters:
    ///   - context: The context used to materialize and read the entity.
    ///   - objectID: The object identifier of the `AuthRequestEntity`.
    /// - Returns: Valid authentication request data, or `nil` on failure.
    static func of(
        context: NSManagedObjectContext,
        objectID: NSManagedObjectID
    ) async -> RequestModel.AuthRequestData? {
        let env = Environment.create()

        do {
            try env.checkCoreDataError()

            let config = try await env.config()
            let externalAuth = try await env.externalAuth()
            let internalAuth = try await env.internalAuth()

            let requestId = try await withEntity(
                context: context,
                objectID: objectID,
                as: AuthRequestEntity.self
            ) { entity in
                entity.requestId ?? UUID().uuidString
            }

            return RequestModel.AuthRequestData(
                url: authURL(config.apiUrl),
                requestId: requestId,
                authHeader: externalAuth.header,
                currentAcid: internalAuth.currentAcid,
                startAnonSession: internalAuth.startAnonSession
            )
        } catch {
            CoreLog.error(#function, error: error)
            return nil
        }
    }
}

extension RequestModel {

    /// Represents the data required to authorize a user session.
    ///
    /// - Properties:
    ///   - url: API endpoint URL.
    ///   - requestId: Unique request ID.
    ///   - authHeader: Authorization header.
    ///   - currentAcid: Current user ACID.
    ///   - startAnonSession: Anonymous session start time in Unix time.
    struct AuthRequestData: RequestData {
        typealias Response = ResponseModel.ResponseWithAuth

        let url: String
        let requestId: String
        let authHeader: String
        let currentAcid: String?
        let startAnonSession: Int64

        init(
            url: String,
            requestId: String,
            authHeader: String,
            currentAcid: String?,
            startAnonSession: Int64
        ) {
            self.url = url
            self.requestId = requestId
            self.authHeader = authHeader
            self.currentAcid = currentAcid
            self.startAnonSession = startAnonSession
        }

        let requestName: String = Constants.RequestName.authorize
        let successEvent: any SDKEvent = CoreEvents.authenticateSuccessful
        let failedEvent: any SDKEvent = CoreEvents.authenticateFailed
        let eventData: [String: Any?]? = nil
        let logData: [String: Any?]? = nil

        var moduleLogPrefix: String { CoreLog.MODULE_PREFIX }

        var responseType: Response.Type {
            Response.self
        }
    }
}
