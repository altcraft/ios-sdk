//
//  CommonsDbQueriesTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * CommonsDbQueriesTest
 *
 * Positive scenarios:
 *  - test_1: resolveObject returns materialized object for valid permanent ID in the same context.
 *  - test_2: resolveObject returns nil for a temporary (unsaved) object ID.
 *  - test_3: deleteEntity deletes existing entity and returns true.
 *  - test_4: deleteEntity returns true when entity was already deleted.
 *  - test_5: deleteEntity returns true for invalid (temporary) object ID.
 *  - test_6: retryLimit increments retryCount until max, then deletes entity and returns true.
 *  - test_7: retryLimit returns true for invalid (deleted) object ID.
 */

final class CommonsDbQueriesTest: IsolatedTestCase {

    /// Creates a test MobileEventEntity with sane defaults
    @discardableResult
    private func makeEvent(
        userTag: String = "user-1",
        tz: Int16 = 180,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        aci: String? = "client-123",
        name: String? = "open",
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2
    ) throws -> MobileEventEntity {
        let e = MobileEventEntity(context: viewContext)
        e.userTag = userTag
        e.timeZone = tz
        e.time = time
        e.sid = "pixel-777"
        e.altcraftClientID = aci
        e.eventName = name
        e.retryCount = retryCount
        e.maxRetryCount = maxRetryCount
        try viewContext.save()
        return e
    }

    /// test_1: resolveObject returns materialized object for valid permanent ID in the same context
    func test_1_resolveObject_returns_entity_for_permanent_id() throws {
        let created = try makeEvent()
        let id = created.objectID

        var resolved: NSManagedObject?
        viewContext.performAndWait {
            resolved = resolveObject(in: viewContext, from: id)
        }

        XCTAssertNotNil(resolved)
        XCTAssertFalse(resolved!.objectID.isTemporaryID)
        XCTAssertEqual((resolved as? MobileEventEntity)?.eventName, "open")
    }

    /// test_2: resolveObject returns nil for a temporary (unsaved) object ID
    func test_2_resolveObject_returns_nil_for_temporary_id() throws {
        let temp = MobileEventEntity(context: viewContext) // not saved → temporary ID
        var out: NSManagedObject?
        viewContext.performAndWait {
            out = resolveObject(in: viewContext, from: temp.objectID)
        }
        XCTAssertNil(out)
    }

    /// test_3: deleteEntity deletes existing entity and returns true
    func test_3_deleteEntity_deletes_existing_entity_and_returns_true() throws {
        let e = try makeEvent()
        let id = e.objectID

        let exp = expectation(description: "delete existing entity")
        deleteEntity(context: viewContext, objectID: id) { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        let req: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        let all = try viewContext.fetch(req)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_4: deleteEntity returns true when entity was already deleted
    func test_4_deleteEntity_returns_true_when_already_deleted() throws {
        let e = try makeEvent()
        let id = e.objectID
        viewContext.delete(e)
        try viewContext.save()

        let exp = expectation(description: "delete already deleted entity")
        deleteEntity(context: viewContext, objectID: id) { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_5: deleteEntity returns true for invalid (temporary) object ID
    func test_5_deleteEntity_returns_true_for_temporary_id() {
        let temp = MobileEventEntity(context: viewContext) // not saved → temporary ID
        let id = temp.objectID

        let exp = expectation(description: "delete with temporary id returns true")
        deleteEntity(context: viewContext, objectID: id) { ok in
            XCTAssertTrue(ok)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_6: retryLimit increments retryCount until max, then deletes and returns true
    func test_6_retryLimit_increments_until_max_then_deletes() throws {
        let e = try makeEvent(retryCount: 0, maxRetryCount: 2)
        let id = e.objectID

        let exp1 = expectation(description: "retry #1")
        retryLimit(context: viewContext, for: id) { reachedLimit in
            XCTAssertFalse(reachedLimit)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1.0)

        let exp2 = expectation(description: "retry #2")
        retryLimit(context: viewContext, for: id) { reachedLimit in
            XCTAssertFalse(reachedLimit)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)

        let exp3 = expectation(description: "retry #3 → delete")
        retryLimit(context: viewContext, for: id) { reachedLimit in
            XCTAssertTrue(reachedLimit)
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 1.0)

        let req: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        let all = try viewContext.fetch(req)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_7: retryLimit returns true for invalid (deleted) object ID
    func test_7_retryLimit_returns_true_for_invalid_object_id() throws {
        let e = try makeEvent()
        let id = e.objectID
        viewContext.delete(e)
        try viewContext.save()

        let exp = expectation(description: "retryLimit with deleted id")
        retryLimit(context: viewContext, for: id) { reachedLimit in
            XCTAssertTrue(reachedLimit)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }
}
