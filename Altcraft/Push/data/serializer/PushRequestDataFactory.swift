//
//  PushRequestDataFactory.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Builds `PushSubscribeRequestData` using entity details and the push module
/// environment. Safely materializes the `PushSubscribeEntity` by its
/// `NSManagedObjectID` inside the given context.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `PushSubscribeEntity`.
/// - Returns: Valid push subscription request data, or `nil` on failure.
func getPushSubscribeRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.PushSubscribeRequestData? {
    let env = PushEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let token = try await env.currentToken()

        let snapshot = try await withEntity(
            context: context,
            objectID: objectID,
            as: PushSubscribeEntity.self
        ) { entity in
            (
                requestId: entity.requestId ?? "",
                time: entity.time,
                status: entity.status ?? "",
                sync: entity.sync,
                profileFields: decodeAnyMap(entity.profileFields),
                customFields: entity.customFields,
                cats: decodeCats(entity.cats),
                replace: entity.replace,
                skipTriggers: entity.skipTriggers
            )
        }

        let fields = await getFields(
            appFields: [:],
            customFieldsData: snapshot.customFields
        )

        let requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: snapshot.requestId,
            time: snapshot.time,
            provider: token.provider,
            deviceToken: token.token,
            status: snapshot.status,
            sync: snapshot.sync,
            profileFields: snapshot.profileFields,
            fields: fields,
            cats: snapshot.cats,
            replace: snapshot.replace,
            skipTriggers: snapshot.skipTriggers
        )

        guard requestData.isValid else {
            PushLog.error(
                #function,
                error: PushModuleEvents.invalidSubRequestData
            )
            return nil
        }

        return requestData
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

/// Builds `PushEventRequestData` from a `PushEventEntity` identified
/// by its object identifier.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `PushEventEntity`.
/// - Returns: Valid push event request data, or `nil` on failure.
func getPushEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.PushEventRequestData? {
    let env = PushEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let requestData = try await withEntity(
            context: context,
            objectID: objectID,
            as: PushEventEntity.self
        ) { entity -> RequestModel.PushEventRequestData? in
            guard let uid = entity.uid,
                  let type = entity.type else {
                return nil
            }

            let request = RequestModel.PushEventRequestData(
                path: PushConstants.UrlPath.event,
                requestId: entity.requestId ?? "",
                time: entity.time,
                type: type,
                uid: uid
            )

            guard request.isValid else {
                return nil
            }

            return request
        }

        guard let requestData else {
            PushLog.error(
                #function,
                error: PushModuleEvents
                    .invalidPushEventRequestData
            )
            return nil
        }

        return requestData
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}
