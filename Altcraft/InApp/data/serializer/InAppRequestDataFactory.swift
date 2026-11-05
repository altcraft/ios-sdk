//
//  InAppRequestDataFactory.swift
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

/// Builds `InAppSubscribeRequestData` from an `InAppSubscribeEntity`
/// identified by its object identifier.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `InAppSubscribeEntity`.
/// - Returns: Valid in-app subscription request data, or `nil` on failure.
func getInAppSubscribeRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.InAppSubscribeRequestData? {
    let env = InAppEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let snapshot = try await withEntity(
            context: context,
            objectID: objectID,
            as: InAppSubscribeEntity.self
        ) { entity in
            (
                requestId: entity.requestId ?? "",
                time: entity.time,
                deviceId: entity.deviceId ?? "",
                acid: entity.acid ?? "",
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

        let requestData = RequestModel.InAppSubscribeRequestData(
            path: InAppConstants.UrlPath.subscribe,
            requestId: snapshot.requestId,
            time: snapshot.time,
            deviceId: snapshot.deviceId,
            acid: snapshot.acid,
            status: snapshot.status,
            sync: snapshot.sync,
            profileFields: snapshot.profileFields,
            fields: fields,
            cats: snapshot.cats,
            replace: snapshot.replace,
            skipTriggers: snapshot.skipTriggers
        )

        guard requestData.isValid else {
            InAppLog.error(
                #function,
                error: InAppModuleEvents.invalidSubRequestData
            )
            return nil
        }

        return requestData
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Builds `InAppEventRequestData` from an `InAppEventEntity` identified
/// by its object identifier.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `InAppEventEntity`.
/// - Returns: Valid in-app event request data, or `nil` on failure.
func getInAppEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.InAppEventRequestData? {
    let env = InAppEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let storedAuth = try? await env.internalAuth()

        return try await withEntity(
            context: context,
            objectID: objectID,
            as: InAppEventEntity.self
        ) { entity in
            RequestModel.InAppEventRequestData(
                path: InAppConstants.UrlPath.event,
                requestId: entity.requestId ?? "",
                type: entity.type ?? "",
                time: entity.time,
                smid: entity.smid ?? "",
                acid: storedAuth?.currentAcid ?? "",
                data: decodeInAppEventData(entity.data)
            )
        }
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}

/// Builds `InAppPlacesRequestData` using the current persisted
/// in-app synchronization state.
///
/// Uses the supplied request identifier during retries. When no identifier
/// is supplied, a new identifier is generated for the initial request.
///
/// - Parameters:
///   - state: Current persisted in-app synchronization state.
///   - requestId: Existing request identifier used by a retry attempt.
/// - Returns: Valid placement request data, or `nil` on failure.
func getInAppPlacementsRequestData(
    state: InAppModel.InAppsState,
    requestId: String? = nil
) async -> InAppPlacesRequestData? {
    let env = InAppEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        return InAppPlacesRequestData(
            path: InAppConstants.UrlPath.placements,
            requestId: requestId ?? UUID().uuidString,
            acid: state.acid,
            deviceId: state.deviceId,
            lastPublish: state.lastPublish,
            placementRulesChecksum: state.placementRulesChecksum
        )
    } catch {
        InAppLog.error(#function, error: error)
        return nil
    }
}
