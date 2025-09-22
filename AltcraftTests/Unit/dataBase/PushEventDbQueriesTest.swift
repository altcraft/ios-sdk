//
//  PushEventDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushEventDbQueriesTests (iOS 13 compatible)
 *
 * Coverage:
 *  - test_1_addPushEventEntity_createsAndPersistsFields:
 *      Creates a new PushEventEntity, persists scalar fields, and returns the created entity.
 *
 *  - test_2_getAllPushEvents_fetchesAndSortsAscending:
 *      Fetches all events and returns them sorted by "time" ascending.
 *
 *  - test_3_deletePushEvent_removesEntity_andReturnsTrue:
 *      Deletes a given event entity and completes with true on success.
 *
 *  - test_4_pushEventLimit_incrementsBelowMax_andDeletesAtLimit:
 *      Increments retryCount when below max; deletes the row when retryCount >= max.
 *
 *  - test_5_clearOldPushEvents_noOpOrDeletesOldest:
 *      No-op when total count ≤ 500; deletes 100 oldest events when total > 500.
 *
 * Notes:
 *  - Uses CoreDataManager.shared.persistentContainer (production stack).
 *  - Each test runs in its own background context to avoid UI-thread coupling.
 *  - Deterministic ordering is ensured by manually adjusting "time" values after insertion.
 */
final class PushEventDbQueriesTests: XCTestCase {

    // MARK: - Constants

    private let timeoutShort: TimeInterval = 2.5
    private let timeoutLong:  TimeInterval = 6.0

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        wipePushEvents()
    }

    override func tearDown() {
        wipePushEvents()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Batch-deletes PushEventEntity via background context (best effort).
    private func wipePushEvents() {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.pushEventEntityName)
            let req = NSBatchDeleteRequest(fetchRequest: fr)
            req.resultType = .resultTypeObjectIDs
            do {
                if let res = try bg.execute(req) as? NSBatchDeleteResult,
                   let oids = res.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: oids],
                        into: [bg, container.viewContext]
                    )
                }
            } catch {
                // best-effort cleanup
            }
        }
    }

    /// Counts PushEventEntity objects in the given context.
    private func countPushEvents(in ctx: NSManagedObjectContext) -> Int? {
        var result: Int?
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.pushEventEntityName)
            do { result = try ctx.count(for: fr) } catch { result = nil }
        }
        return result
    }

    /// Fetches all PushEventEntity sorted by time asc from the given context.
    private func fetchAllPushEvents(in ctx: NSManagedObjectContext) -> [PushEventEntity] {
        var out: [PushEventEntity] = []
        ctx.performAndWait {
            let fr: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            out = (try? ctx.fetch(fr)) ?? []
        }
        return out
    }

    /// Sets "time" for an entity and saves.
    private func setTime(_ t: Int64, for entity: PushEventEntity, in ctx: NSManagedObjectContext) {
        ctx.performAndWait {
            entity.time = t
            try? ctx.save()
        }
    }

    // MARK: - Tests

    /// addPushEventEntity creates an entity, sets default fields, and returns it via completion.
    func test_1_addPushEventEntity_creates_andReturnsEntity() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let uid = "evt-001"
        let type = "delivered"

        let exp = expectation(description: "add completion")
        var created: PushEventEntity?
        ctx.performAndWait {
            addPushEventEntity(context: ctx, uid: uid, type: type) { e in
                created = e
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertNotNil(created, "Created entity must be returned")
        XCTAssertEqual(created?.uid, uid)
        XCTAssertEqual(created?.type, type)
        XCTAssertEqual(created?.retryCount, 0)
        XCTAssertEqual(created?.maxRetryCount, 15)

        let nowSec = Int64(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(created?.time ?? 0, nowSec - 5)
        XCTAssertLessThanOrEqual(created?.time ?? 0, nowSec + 5)

        // Verify count in the same context
        XCTAssertEqual(countPushEvents(in: ctx), 1)
    }

    /// getAllPushEvents returns rows sorted by time ascending.
    func test_2_getAllPushEvents_sortsAscendingByTime() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Insert three events
        let ids = ["A", "B", "C"]
        for id in ids {
            let exp = expectation(description: "add \(id)")
            addPushEventEntity(context: ctx, uid: id, type: "opened") { _ in exp.fulfill() }
            waitForExpectations(timeout: timeoutShort)
        }

        // Make time deterministic: A=200, B=100, C=300
        let all = fetchAllPushEvents(in: ctx)
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.uid ?? UUID().uuidString, $0) })
        setTime(200, for: map["A"]!, in: ctx)
        setTime(100, for: map["B"]!, in: ctx)
        setTime(300, for: map["C"]!, in: ctx)

        let expFetch = expectation(description: "fetch all")
        getAllPushEvents(context: ctx) { rows in
            XCTAssertEqual(rows.map { $0.uid }, ["B", "A", "C"])
            expFetch.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// deletePushEvent deletes the entity and returns true.
    func test_3_deletePushEvent_deletes_andReturnsTrue() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Seed one event
        let expAdd = expectation(description: "add")
        addPushEventEntity(context: ctx, uid: "DEL", type: "delivered") { _ in expAdd.fulfill() }
        waitForExpectations(timeout: timeoutShort)
        XCTAssertEqual(countPushEvents(in: ctx), 1)

        guard let row = fetchAllPushEvents(in: ctx).first else {
            XCTFail("Expected one row"); return
        }

        let expDel = expectation(description: "delete")
        deletePushEvent(context: ctx, entity: row) { ok in
            XCTAssertTrue(ok, "deletePushEvent must return true on success")
            expDel.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(countPushEvents(in: ctx), 0, "Row must be deleted")
    }

    /// pushEventLimit increments below max and deletes at/above max.
    func test_4_pushEventLimit_incrementsBelowMax_andDeletesAtLimit() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Seed one
        let expAdd = expectation(description: "add")
        addPushEventEntity(context: ctx, uid: "LIM-1", type: "opened") { _ in expAdd.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        guard let row = fetchAllPushEvents(in: ctx).first else {
            XCTFail("Expected one row"); return
        }

        // Below max: increment, completion(false)
        ctx.performAndWait {
            row.retryCount = 2
            row.maxRetryCount = 3
            try? ctx.save()
        }

        let expInc = expectation(description: "increment")
        pushEventLimit(context: ctx, for: row) { deleted in
            XCTAssertFalse(deleted, "Must not delete when retryCount < max")
            expInc.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        ctx.performAndWait {
            XCTAssertEqual(row.retryCount, 3, "retryCount must be incremented by 1")
        }

        // At limit: delete, completion(true)
        ctx.performAndWait {
            row.retryCount = row.maxRetryCount // equals -> should delete
            try? ctx.save()
        }

        let expDel = expectation(description: "delete at limit")
        pushEventLimit(context: ctx, for: row) { deleted in
            XCTAssertTrue(deleted, "Must delete when retryCount >= max")
            expDel.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(countPushEvents(in: ctx), 0, "Entity must be deleted at/over limit")
    }

    /// clearOldPushEvents: no-op when total <= 500; delete 100 oldest when total > 500.
    func test_5_clearOldPushEvents_noopWhenLE500_andDeletes100WhenGT500() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Case 1: total <= 500 -> no deletion
        // Seed 5 events
        for i in 0..<5 {
            let exp = expectation(description: "add small \(i)")
            addPushEventEntity(context: ctx, uid: "S\(i)", type: "opened") { _ in exp.fulfill() }
            waitForExpectations(timeout: timeoutShort)
        }
        XCTAssertEqual(countPushEvents(in: ctx), 5)

        let expNoop = expectation(description: "clear small")
        clearOldPushEvents(context: ctx) {
            expNoop.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
        XCTAssertEqual(countPushEvents(in: ctx), 5, "No deletions expected when total <= 500")

        // Case 2: total > 500 -> delete 100 oldest by time asc
        // Seed 500 more (S0..S499)
        for i in 0..<500 {
            let exp = expectation(description: "add bulk \(i)")
            addPushEventEntity(context: ctx, uid: "B\(i)", type: "delivered") { _ in exp.fulfill() }
            waitForExpectations(timeout: timeoutShort)
        }
        XCTAssertEqual(countPushEvents(in: ctx), 505)

        // Make oldest 100 clearly the earliest by setting their time to [1..100]
        let all = fetchAllPushEvents(in: ctx)
        // Ensure we have at least 100
        XCTAssertGreaterThanOrEqual(all.count, 100)
        for i in 0..<100 {
            setTime(Int64(i + 1), for: all[i], in: ctx)
        }

        let expClear = expectation(description: "clear big")
        clearOldPushEvents(context: ctx) {
            expClear.fulfill()
        }
        waitForExpectations(timeout: timeoutLong)

        // Expect exactly 405 left
        XCTAssertEqual(countPushEvents(in: ctx), 405, "Exactly 100 oldest must be deleted when total > 500")

        // Validate that the smallest remaining time is >= 101
        let remaining = fetchAllPushEvents(in: ctx)
        let minTime = remaining.first?.time ?? 0
        XCTAssertGreaterThanOrEqual(minTime, 101)
    }
}

