//
//  ProfileRequestDataFactory.swift
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

/// Builds `ProfileUpdateRequestData` from a `ProfileUpdateEntity`
/// identified by its object identifier.
///
/// - Parameters:
///   - context: The context used to materialize and read the entity.
///   - objectID: The object identifier of the `ProfileUpdateEntity`.
/// - Returns: Valid profile update request data, or `nil` on failure.
func getProfileUpdateRequestData(
    context: NSManagedObjectContext,
    objectID: NSManagedObjectID
) async -> RequestModel.ProfileUpdateRequestData? {
    let env = ProfileEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        return try await withEntity(
            context: context,
            objectID: objectID,
            as: ProfileUpdateEntity.self
        ) { entity in
            RequestModel.ProfileUpdateRequestData(
                path: ProfileConstants.UrlPath.update,
                requestId: entity.requestId ?? "",
                profileFields: decodeAnyMap(entity.profileFields),
                skipTriggers: entity.skipTriggers
            )
        }
    } catch {
        return nil
    }
}
