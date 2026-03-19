//
//  CommonsDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * CommonsDbQueriesTests
 *
 * Positive scenarios:
 * - test_1: resolveObject returns materialized object for valid permanent ID in the same context.
 * - test_2: resolveObject returns nil for temporary unsaved object ID.
 * - test_3: deleteEntity deletes existing entity and returns true.
 * - test_4: deleteEntity returns true when entity was already deleted.
 * - test_5: deleteEntity returns true for temporary object ID.
 * - test_6: retryLimit increments retryCount until max then deletes entity and returns true.
 * - test_7: retryLimit returns true for invalid deleted object ID.
 *
 */
final class CommonsDbQueriesTests: IsolatedTestCase {

    @discardableResult
    private func makeEvent(
        userTag: String = "user-1",
        timeZone: Int16 = 180,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        altcraftClientID: String? = "client-123",
        eventName: String? = "open",
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2
    ) throws -> NSManagedObjectID {
        var objectID: NSManagedObjectID?

        viewContext.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: Constants.EntityNames.mobileEventEntity,
                into: viewContext
            )

            entity.setValue(userTag, forKey: "userTag")
            entity.setValue(timeZone, forKey: "timeZone")
            entity.setValue(time, forKey: "time")
            entity.setValue("pixel-777", forKey: "sid")
            entity.setValue(altcraftClientID, forKey: "altcraftClientID")
            entity.setValue(eventName, forKey: "eventName")
            entity.setValue(retryCount, forKey: "retryCount")
            entity.setValue(maxRetryCount, forKey: "maxRetryCount")

            do {
                if entity.objectID.isTemporaryID {
                    try viewContext.obtainPermanentIDs(for: [entity])
                }
                try viewContext.save()
                objectID = entity.objectID
            } catch {
                XCTFail("Failed to save MobileEventEntity: \(error)")
            }
        }

        return try XCTUnwrap(objectID)
    }

    private func fetchAllEvents() throws -> [MobileEventEntity] {
        var objects: [MobileEventEntity] = []

        viewContext.performAndWait {
            let request = NSFetchRequest<MobileEventEntity>(
                entityName: Constants.EntityNames.mobileEventEntity
            )
            objects = (try? viewContext.fetch(request)) ?? []
        }

        return objects
    }

    private func fetchEvent(by objectID: NSManagedObjectID) throws -> MobileEventEntity? {
        var object: MobileEventEntity?

        viewContext.performAndWait {
            object = resolveObject(in: viewContext, from: objectID) as? MobileEventEntity
        }

        return object
    }

    private func deleteFromContext(_ objectID: NSManagedObjectID) throws {
        viewContext.performAndWait {
            guard let object = resolveObject(in: viewContext, from: objectID) else {
                return
            }

            viewContext.delete(object)

            do {
                if viewContext.hasChanges {
                    try viewContext.save()
                }
            } catch {
                XCTFail("Failed to delete MobileEventEntity: \(error)")
            }
        }
    }

    /// test_1: resolveObject returns materialized object for valid permanent ID in the same context
    func test_1_resolveObject_returns_materialized_object_for_valid_permanent_id_in_the_same_context() throws {
        let objectID = try makeEvent()

        var resolved: NSManagedObject?
        viewContext.performAndWait {
            resolved = resolveObject(in: viewContext, from: objectID)
        }

        XCTAssertNotNil(resolved)
        XCTAssertFalse(resolved?.objectID.isTemporaryID ?? true)
        XCTAssertEqual((resolved as? MobileEventEntity)?.eventName, "open")
    }

    /// test_2: resolveObject returns nil for temporary unsaved object ID
    func test_2_resolveObject_returns_nil_for_temporary_unsaved_object_id() {
        let temporary = NSEntityDescription.insertNewObject(
            forEntityName: Constants.EntityNames.mobileEventEntity,
            into: viewContext
        )

        var resolved: NSManagedObject?
        viewContext.performAndWait {
            resolved = resolveObject(in: viewContext, from: temporary.objectID)
        }

        XCTAssertNil(resolved)
    }

    /// test_3: deleteEntity deletes existing entity and returns true
    func test_3_deleteEntity_deletes_existing_entity_and_returns_true() async throws {
        let objectID = try makeEvent()

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)

        let all = try fetchAllEvents()
        XCTAssertTrue(all.isEmpty)
    }

    /// test_4: deleteEntity returns true when entity was already deleted
    func test_4_deleteEntity_returns_true_when_entity_was_already_deleted() async throws {
        let objectID = try makeEvent()
        try deleteFromContext(objectID)

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }

    /// test_5: deleteEntity returns true for temporary object ID
    func test_5_deleteEntity_returns_true_for_temporary_object_id() async {
        let temporary = NSEntityDescription.insertNewObject(
            forEntityName: Constants.EntityNames.mobileEventEntity,
            into: viewContext
        )
        let objectID = temporary.objectID

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }

    /// test_6: retryLimit increments retryCount until max then deletes entity and returns true
    func test_6_retryLimit_increments_retry_count_until_max_then_deletes_entity_and_returns_true() async throws {
        let objectID = try makeEvent(retryCount: 0, maxRetryCount: 2)

        let firstResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertFalse(firstResult)

        let firstEntity = try XCTUnwrap(fetchEvent(by: objectID))
        XCTAssertEqual(firstEntity.retryCount, 1)

        let secondResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertFalse(secondResult)

        let secondEntity = try XCTUnwrap(fetchEvent(by: objectID))
        XCTAssertEqual(secondEntity.retryCount, 2)

        let thirdResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertTrue(thirdResult)

        let all = try fetchAllEvents()
        XCTAssertTrue(all.isEmpty)
    }

    /// test_7: retryLimit returns true for invalid deleted object ID
    func test_7_retryLimit_returns_true_for_invalid_deleted_object_id() async throws {
        let objectID = try makeEvent()
        try deleteFromContext(objectID)

        let result = await retryLimit(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }
}
