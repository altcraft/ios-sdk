//
//  PushEventTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushEventTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_addPushEventEntity_persists_all_fields_and_defaults
 *  - test_2_getAllPushEvents_sorts_by_time_ascending
 *  - test_3_deletePushEvent_removes_entity
 *  - test_4_pushEventLimit_increments_then_deletes_at_limit
 *  - test_5_clearOldPushEvents_deletes_100_when_count_over_500
 *  - test_6_sendAllPushEvents_when_empty_calls_completion
 *
 * Edge:
 *  - test_7_createPushEvent_without_uid_emits_error_and_does_not_insert
 *
 * Notes:
 *  - Uses production CoreData stack (CoreDataManager.shared).
 *  - No network stubbing required; tests avoid calling the real network paths.
 *  - Thread usage is limited to background contexts; assertions fetch via same ctx.
 */
final class PushEventTests: XCTestCase {

    // MARK: - Helpers

    private func wipePushEvents() {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.pushEventEntityName)
            let del = NSBatchDeleteRequest(fetchRequest: fr)
            del.resultType = .resultTypeObjectIDs
            do {
                if let res = try bg.execute(del) as? NSBatchDeleteResult,
                   let oids = res.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: oids],
                                                        into: [bg, container.viewContext])
                }
            } catch {
                // best-effort cleanup
            }
        }
    }

    private func count(in ctx: NSManagedObjectContext) -> Int? {
        var result: Int?
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.pushEventEntityName)
            do { result = try ctx.count(for: fr) } catch { result = nil }
        }
        return result
    }

    private func fetchAll(in ctx: NSManagedObjectContext) -> [PushEventEntity] {
        var out: [PushEventEntity] = []
        ctx.performAndWait {
            let fr: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            out = (try? ctx.fetch(fr)) ?? []
        }
        return out
    }

    private func setTime(_ t: Int64, for e: PushEventEntity, in ctx: NSManagedObjectContext) {
        ctx.performAndWait {
            e.time = t
            try? ctx.save()
        }
    }

    private func normalizedFunc(_ s: String?) -> String? {
        guard let s = s else { return nil }
        return s.hasSuffix("()") ? String(s.dropLast(2)) : s
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        wipePushEvents()
    }

    override func tearDown() {
        wipePushEvents()
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_addPushEventEntity_persists_all_fields_and_defaults
    func test_1_addPushEventEntity_persists_all_fields_and_defaults() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let exp = expectation(description: "add")
        ctx.performAndWait {
            addPushEventEntity(context: ctx, uid: "U1", type: "delivered") { _ in
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: 1.5)

        let all = fetchAll(in: ctx)
        XCTAssertEqual(all.count, 1)
        let e = all[0]
        XCTAssertEqual(e.uid, "U1")
        XCTAssertEqual(e.type, "delivered")
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)

        let now = Int64(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(e.time, now - 5)
        XCTAssertLessThanOrEqual(e.time, now + 5)
    }

    /// test_2_getAllPushEvents_sorts_by_time_ascending
    func test_2_getAllPushEvents_sorts_by_time_ascending() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Insert three
        let expA = expectation(description: "A")
        addPushEventEntity(context: ctx, uid: "A", type: "delivered") { _ in expA.fulfill() }
        waitForExpectations(timeout: 1.0)
        let expB = expectation(description: "B")
        addPushEventEntity(context: ctx, uid: "B", type: "delivered") { _ in expB.fulfill() }
        waitForExpectations(timeout: 1.0)
        let expC = expectation(description: "C")
        addPushEventEntity(context: ctx, uid: "C", type: "delivered") { _ in expC.fulfill() }
        waitForExpectations(timeout: 1.0)

        // Force times: A=300, B=100, C=200
        let map = Dictionary(uniqueKeysWithValues: fetchAll(in: ctx).map { (($0.uid ?? UUID().uuidString), $0) })
        setTime(300, for: map["A"]!, in: ctx)
        setTime(100, for: map["B"]!, in: ctx)
        setTime(200, for: map["C"]!, in: ctx)

        let expFetch = expectation(description: "fetch")
        getAllPushEvents(context: ctx) { rows in
            XCTAssertEqual(rows.map { $0.uid }, ["B", "C", "A"])
            expFetch.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    /// test_3_deletePushEvent_removes_entity
    func test_3_deletePushEvent_removes_entity() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let expAdd = expectation(description: "add")
        addPushEventEntity(context: ctx, uid: "DEL", type: "delivered") { _ in expAdd.fulfill() }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(count(in: ctx), 1)

        let row = fetchAll(in: ctx).first!
        let expDel = expectation(description: "del")
        deletePushEvent(context: ctx, entity: row) { ok in
            XCTAssertTrue(ok)
            expDel.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(count(in: ctx), 0)
    }

    /// test_4_pushEventLimit_increments_then_deletes_at_limit
    func test_4_pushEventLimit_increments_then_deletes_at_limit() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let expAdd = expectation(description: "add")
        addPushEventEntity(context: ctx, uid: "LIM", type: "delivered") { _ in expAdd.fulfill() }
        waitForExpectations(timeout: 1.0)
        let row = fetchAll(in: ctx).first!

        // Below max → increment
        ctx.performAndWait {
            row.retryCount = 3
            row.maxRetryCount = 5
            try? ctx.save()
        }
        let expInc = expectation(description: "inc")
        pushEventLimit(context: ctx, for: row) { deleted in
            XCTAssertFalse(deleted)
            expInc.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        ctx.performAndWait { XCTAssertEqual(row.retryCount, 4) }

        // At/over max → delete
        ctx.performAndWait {
            row.retryCount = row.maxRetryCount
            try? ctx.save()
        }
        let expDel = expectation(description: "del")
        pushEventLimit(context: ctx, for: row) { deleted in
            XCTAssertTrue(deleted)
            expDel.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(count(in: ctx), 0)
    }

    /// test_5_clearOldPushEvents_deletes_100_when_count_over_500
    func test_5_clearOldPushEvents_deletes_100_when_count_over_500() throws {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Seed 550 items with time = 1..550
        let target = 550
        let expAll = expectation(description: "seed")
        var seededErrors: Error?
        ctx.perform {
            for i in 1...target {
                let e = PushEventEntity(context: ctx)
                e.uid = "U\(i)"
                e.type = "delivered"
                e.time = Int64(i)
                e.retryCount = 0
                e.maxRetryCount = 15
            }
            do {
                try ctx.save()
            } catch {
                seededErrors = error
            }
            expAll.fulfill()
        }
        waitForExpectations(timeout: 3.0)
        if let err = seededErrors { throw err }
        XCTAssertEqual(count(in: ctx), target)

        let expClear = expectation(description: "clear")
        clearOldPushEvents(context: ctx) {
            expClear.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(count(in: ctx), 450, "Must delete 100 oldest when >500")

        // Verify oldest removed: minimal time should now be 101
        let remaining = fetchAll(in: ctx)
        XCTAssertEqual(remaining.first?.time, 101)
    }

    /// test_6_sendAllPushEvents_when_empty_calls_completion
    func test_6_sendAllPushEvents_when_empty_calls_completion() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Ensure empty
        XCTAssertEqual(count(in: ctx), 0)

        let exp = expectation(description: "completion")
        PushEvent.shared.sendAllPushEvents(context: ctx) {
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    /// test_7_createPushEvent_without_uid_emits_error_and_does_not_insert
    func test_7_createPushEvent_without_uid_emits_error_and_does_not_insert() {
        // Spy events
        var captured: [Event] = []
        SDKEvents.shared.subscribe { ev in captured.append(ev) }

        // Attempt to create without uid
        let before = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        let beforeCount = count(in: before) ?? -1

        PushEvent.shared.createPushEvent(userInfo: [:], type: "delivered")

        // Give the async getContext/add path a moment (though it should early-exit before insertion).
        // In practice, missing uid returns immediately without background work.
        // Still, wait briefly to be safe.
        let exp = expectation(description: "settle")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        let after = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        let afterCount = count(in: after) ?? -1
        XCTAssertEqual(beforeCount, afterCount, "No entity must be inserted on missing uid")

        // Check the last event is an ErrorEvent from createPushEvent
        XCTAssertFalse(captured.isEmpty)
        XCTAssertTrue(captured.last is ErrorEvent)
        XCTAssertEqual(normalizedFunc(captured.last?.function), "createPushEvent")
    }
}

