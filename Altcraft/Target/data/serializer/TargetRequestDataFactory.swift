//
//  TargetRequestDataFactory.swift
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

/// Builds `TargetEventRequestData` from a `TargetEntity` identified
/// by its object identifier.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `TargetEntity`.
/// - Returns: Valid target (mobile) event request data, or `nil` on failure.
func getTargetEventRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.TargetEventRequestData? {
    let env = TargetEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let result = try await withEntity(
            context: context,
            objectID: objectID,
            as: TargetEntity.self
        ) { entity -> (
            sid: String,
            name: String,
            requestId: String,
            parts: [Part]
        )? in
            guard let sid = entity.sid,
                  let name = entity.eventName else {
                return nil
            }

            return (
                sid: sid,
                name: name,
                requestId: entity.requestId ?? "",
                parts: PartsFactory.createTargetEventParts(
                    from: TargetEventSnapshot(entity: entity)
                )
            )
        }

        guard let result else {
            return nil
        }

        return RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: result.requestId,
            sid: result.sid,
            name: result.name,
            parts: result.parts
        )
    } catch {
        return nil
    }
}
