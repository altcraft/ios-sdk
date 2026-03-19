//
//  CommonsDbQueriesTest.swift
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
* CommonsDbQueriesTest
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
final class CommonsDbQueriesTest: IsolatedTestCase {

    @discardableResult
    private func makeEvent(
        userTag: String = "user-1",
        timeZone: Int16 = 180,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        altcraftClientID: String? = "client-123",
        eventName: String? = "open",
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2
    ) throws -> MobileEventEntity {
        let entity = MobileEventEntity(context: viewContext)
        entity.userTag = userTag
        entity.timeZone = timeZone
        entity.time = time
        entity.sid = "pixel-777"
        entity.altcraftClientID = altcraftClientID
        entity.eventName = eventName
        entity.retryCount = retryCount
        entity.maxRetryCount = maxRetryCount
        try viewContext.save()
        return entity
    }

    /// test_1: resolveObject returns materialized object for valid permanent ID in the same context
    func test_1_resolve_object_returns_materialized_object_for_valid_permanent_id_in_same_context() throws {
        let created = try makeEvent()
        let objectID = created.objectID

        var resolved: NSManagedObject?
        viewContext.performAndWait {
            resolved = resolveObject(in: viewContext, from: objectID)
        }

        XCTAssertNotNil(resolved)
        XCTAssertFalse(resolved?.objectID.isTemporaryID ?? true)
        XCTAssertEqual((resolved as? MobileEventEntity)?.eventName, "open")
    }

    /// test_2: resolveObject returns nil for temporary unsaved object ID
    func test_2_resolve_object_returns_nil_for_temporary_unsaved_object_id() {
        let temporary = MobileEventEntity(context: viewContext)

        var resolved: NSManagedObject?
        viewContext.performAndWait {
            resolved = resolveObject(in: viewContext, from: temporary.objectID)
        }

        XCTAssertNil(resolved)
    }

    /// test_3: deleteEntity deletes existing entity and returns true
    func test_3_delete_entity_deletes_existing_entity_and_returns_true() async throws {
        let entity = try makeEvent()
        let objectID = entity.objectID

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)

        let request: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        let all = try viewContext.fetch(request)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_4: deleteEntity returns true when entity was already deleted
    func test_4_delete_entity_returns_true_when_entity_was_already_deleted() async throws {
        let entity = try makeEvent()
        let objectID = entity.objectID

        viewContext.delete(entity)
        try viewContext.save()

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }

    /// test_5: deleteEntity returns true for temporary object ID
    func test_5_delete_entity_returns_true_for_temporary_object_id() async {
        let temporary = MobileEventEntity(context: viewContext)
        let objectID = temporary.objectID

        let result = await deleteEntity(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }

    /// test_6: retryLimit increments retryCount until max then deletes entity and returns true
    func test_6_retry_limit_increments_retry_count_until_max_then_deletes_entity_and_returns_true() async throws {
        let entity = try makeEvent(retryCount: 0, maxRetryCount: 2)
        let objectID = entity.objectID

        let firstResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertFalse(firstResult)

        let secondResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertFalse(secondResult)

        let thirdResult = await retryLimit(
            context: viewContext,
            objectID: objectID
        )
        XCTAssertTrue(thirdResult)

        let request: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        let all = try viewContext.fetch(request)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_7: retryLimit returns true for invalid deleted object ID
    func test_7_retry_limit_returns_true_for_invalid_deleted_object_id() async throws {
        let entity = try makeEvent()
        let objectID = entity.objectID

        viewContext.delete(entity)
        try viewContext.save()

        let result = await retryLimit(
            context: viewContext,
            objectID: objectID
        )

        XCTAssertTrue(result)
    }
}
