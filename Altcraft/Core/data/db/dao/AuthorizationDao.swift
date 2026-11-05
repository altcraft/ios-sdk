//
//  AuthorizationDao.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Adds or updates the single stored authentication entity.
///
/// If an authentication entity already exists, its fields are updated.
/// Otherwise, a new entity is created.
func addAuthenticationEntity(
    currentAcid: String,
    anonimAcid: String,
    deviceId: String,
    currentUserTag: String?,
    startAnonSession: Int64
) async {
    do {
        try await CoreDataManager.shared.performBackgroundTask { context in
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            let entity = try context.fetch(request).first
                ?? AuthenticationEntity(context: context)

            entity.currentAcid = currentAcid
            entity.anonimAcid = anonimAcid
            entity.deviceId = deviceId
            entity.currentUserTag = currentUserTag
            entity.startAnonSession = startAnonSession

            if context.hasChanges {
                try context.save()
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Returns internal authentication data built from the stored entity.
///
/// All fields are read on the context's queue; the returned value is a plain
/// value type, safe to use across concurrency domains.
///
/// - Parameter context: Managed object context used for the fetch.
/// - Returns: Internal authentication data, or `nil` when the entity is
///   missing or required fields are empty.
func getInternalAuthData(
    context: NSManagedObjectContext
) async -> InternalAuthData? {
    do {
        return try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            guard let entity = try context.fetch(request).first,
                  let currentAcid = entity.currentAcid,
                  let anonimAcid = entity.anonimAcid,
                  let deviceId = entity.deviceId
            else {
                return nil
            }

            return InternalAuthData(
                currentAcid: currentAcid,
                anonimAcid: anonimAcid,
                deviceId: deviceId,
                currentUserTag: entity.currentUserTag,
                startAnonSession: entity.startAnonSession,
                isTest: entity.isTest
            )
        }
    } catch {
        CoreLog.error(#function, error: error)
        return nil
    }
}

/// Checks whether an authentication entity exists.
///
/// - Parameter context: Managed object context used for the fetch.
/// - Returns: `true` when at least one entity exists.
func authenticationEntityExists(
    context: NSManagedObjectContext
) async -> Bool {
    do {
        return try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            return try context.fetch(request).first != nil
        }
    } catch {
        CoreLog.error(#function, error: error)
        return false
    }
}

/// Updates `currentAcid` in the stored authentication entity.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - acid: New current ACID value.
func updateCurrentAcid(
    context: NSManagedObjectContext,
    acid: String
) async {
    do {
        try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.currentAcid = acid

                if context.hasChanges {
                    try context.save()
                }
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Updates `currentUserTag` in the stored authentication entity.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - tag: New current user tag value.
func updateCurrentTag(
    context: NSManagedObjectContext,
    tag: String
) async {
    do {
        try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.currentUserTag = tag

                if context.hasChanges {
                    try context.save()
                }
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Updates `anonimAcid` in the stored authentication entity.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - acid: New anonymous ACID value.
func updateAnonAcid(
    context: NSManagedObjectContext,
    acid: String
) async {
    do {
        try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.anonimAcid = acid

                if context.hasChanges {
                    try context.save()
                }
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Updates `isTest` in the stored authentication entity.
///
/// - Parameters:
///   - context: Managed object context used for the operation.
///   - isTest: New test mode value.
func updateIsTest(
    context: NSManagedObjectContext,
    isTest: Bool
) async {
    do {
        try await context.performAsync {
            let request = AuthenticationEntity.fetchRequest()
            request.fetchLimit = 1

            if let entity = try context.fetch(request).first {
                entity.isTest = isTest

                if context.hasChanges {
                    try context.save()
                }
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}

/// Deletes the stored authentication entity.
///
/// Rows are removed with fetch-and-delete: `NSBatchDeleteRequest` is not
/// supported by the in-memory stores used by the test bundle and can raise
/// an Objective-C exception instead of a regular Swift error.
///
/// - Parameter context: Managed object context used for the delete operation.
func deleteAuthenticationEntity(
    context: NSManagedObjectContext
) async {
    do {
        try await context.performAsync {
            let request = NSFetchRequest<NSManagedObject>(
                entityName: Constants.EntityNames.authenticationEntity
            )
            request.includesPropertyValues = false

            let results = try context.fetch(request)
            results.forEach(context.delete)

            if context.hasChanges {
                try context.save()
            }
        }
    } catch {
        CoreLog.error(#function, error: error)
    }
}
