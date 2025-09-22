//
//  SubscribeDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * SubscribeDbQueriesTests (iOS 13 compatible)
 *
 * Coverage (concise, with explicit test names):
 *  - test_1_addSubscribeEntity_persistsAllFields_andEncodesBlobs:
 *      Persists scalar fields, encodes blob fields, invokes completion.
 *  - test_2_getAllSubscribeByTag_filtersAndSortsAscending:
 *      Filters by userTag and returns rows sorted by "time" ascending.
 *  - test_3_deleteSubscribe_removesEntity_andReturnsTrue:
 *      Deletes a specific row and returns true on success.
 *  - test_4_subscribeLimit_incrementsBelowMax_andDeletesAtLimit:
 *      Increments retryCount when below max; deletes the row at/over the limit.
 *
 * Notes:
 *  - Uses CoreDataManager.shared.persistentContainer (production stack).
 *  - Each test uses its own background context to avoid merge assumptions.
 *  - Time ordering is made deterministic by adjusting "time" values post-insert.
 */
final class SubscribeDbQueriesTests: XCTestCase {

    // MARK: - Constants

    private let timeoutShort: TimeInterval = 2.5

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        wipeSubscribe()
    }

    override func tearDown() {
        wipeSubscribe()
        super.tearDown()
    }

    // MARK: - Helpers

    /// Batch-deletes SubscribeEntity via background context.
    private func wipeSubscribe() {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribeEntityName)
            let req = NSBatchDeleteRequest(fetchRequest: fr)
            req.resultType = .resultTypeObjectIDs
            do {
                if let res = try bg.execute(req) as? NSBatchDeleteResult,
                   let oids = res.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: oids],
                                                        into: [bg, container.viewContext])
                }
            } catch {
                // best-effort cleanup
            }
        }
    }

    /// Counts SubscribeEntity objects in the provided context.
    private func countSubscribe(in ctx: NSManagedObjectContext) -> Int? {
        var result: Int?
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribeEntityName)
            do { result = try ctx.count(for: fr) } catch { result = nil }
        }
        return result
    }

    /// Fetches all SubscribeEntity rows sorted by time asc in the provided context.
    private func fetchAllSubscribe(in ctx: NSManagedObjectContext) -> [SubscribeEntity] {
        var out: [SubscribeEntity] = []
        ctx.performAndWait {
            let fr: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            out = (try? ctx.fetch(fr)) ?? []
        }
        return out
    }

    /// Adjusts "time" field of the given entity and saves.
    private func setTime(_ t: Int64, for entity: SubscribeEntity, in ctx: NSManagedObjectContext) {
        ctx.performAndWait {
            entity.time = t
            try? ctx.save()
        }
    }

    // MARK: - Tests

    /// addSubscribeEntity persists fields and blob encodings; completion must be called.
    func test_1_addSubscribeEntity_persistsAllFields_andEncodesBlobs() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let userTag = "user_A"
        let status = "active"
        let sync = 2
        let profile: [String: Any?] = ["age": 30, "city": "AMS"]
        let custom:  [String: Any?] = ["utm": "spring-campaign", "score": 9.5]
        let cats: [CategoryData] = [
            CategoryData(name: "news", active: true),
            CategoryData(name: "promo", active: false)
        ]
        let replace = true
        let skip = false
        let uid = "req-001"

        let exp = expectation(description: "add completion")
        ctx.performAndWait {
            addSubscribeEntity(
                context: ctx,
                userTag: userTag,
                status: status,
                sync: sync,
                profileFields: profile,
                customFields: custom,
                cats: cats,
                replace: replace,
                skipTriggers: skip,
                uid: uid
            ) {
                exp.fulfill()
            }
        }
        waitForExpectations(timeout: timeoutShort)

        // Verify persisted data in the same context
        let all = fetchAllSubscribe(in: ctx)
        XCTAssertEqual(all.count, 1, "One row expected after addSubscribeEntity")

        guard let e = all.first else { return }
        XCTAssertEqual(e.userTag, userTag)
        XCTAssertEqual(e.status, status)
        XCTAssertEqual(e.sync, Int16(sync))
        XCTAssertEqual(e.replace, replace)
        XCTAssertEqual(e.skipTriggers, skip)
        XCTAssertEqual(e.uid, uid)
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)

        // Time must be near "now" (loose check)
        let nowSec = Int64(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(e.time, nowSec - 5)
        XCTAssertLessThanOrEqual(e.time, nowSec + 5)

        // Encoded blobs existence (we don't decode here; just ensure non-nil when inputs provided)
        XCTAssertNotNil(e.cats, "cats must be encoded")
        XCTAssertNotNil(e.profileFields, "profileFields must be encoded")
        XCTAssertNotNil(e.customFields, "customFields must be encoded")
    }

    /// getAllSubscribeByTag filters by userTag and returns items sorted by "time" ascending.
    func test_2_getAllSubscribeByTag_filtersAndSortsAscending() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Insert 3 rows: two for tag "X", one for tag "Y".
        let expA = expectation(description: "add A")
        addSubscribeEntity(
            context: ctx,
            userTag: "X",
            status: "ok",
            sync: 0,
            profileFields: nil,
            customFields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil,
            uid: "A"
        ) { expA.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        let expB = expectation(description: "add B")
        addSubscribeEntity(
            context: ctx,
            userTag: "X",
            status: "ok",
            sync: 0,
            profileFields: nil,
            customFields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil,
            uid: "B"
        ) { expB.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        let expC = expectation(description: "add C")
        addSubscribeEntity(
            context: ctx,
            userTag: "Y",
            status: "ok",
            sync: 0,
            profileFields: nil,
            customFields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil,
            uid: "C"
        ) { expC.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        // Make time deterministic: X:A=100, X:B=300, Y:C=200
        let all = fetchAllSubscribe(in: ctx)
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.uid ?? UUID().uuidString, $0) })
        setTime(100, for: map["A"]!, in: ctx)
        setTime(300, for: map["B"]!, in: ctx)
        setTime(200, for: map["C"]!, in: ctx)

        // Fetch by tag X and assert ascending order by time -> A(100), B(300)
        let expFetch = expectation(description: "fetch by tag X")
        getAllSubscribeByTag(context: ctx, userTag: "X") { rows in
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows[0].uid, "A")
            XCTAssertEqual(rows[1].uid, "B")
            expFetch.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// deleteSubscribe removes the entity and returns true.
    func test_3_deleteSubscribe_removesEntity_andReturnsTrue() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Insert one row
        let expAdd = expectation(description: "add")
        addSubscribeEntity(
            context: ctx,
            userTag: "Z",
            status: "ok",
            sync: 1,
            profileFields: nil,
            customFields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil,
            uid: "DEL"
        ) { expAdd.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        var before = countSubscribe(in: ctx) ?? -1
        XCTAssertEqual(before, 1)

        // Delete
        let row = fetchAllSubscribe(in: ctx).first!
        let expDel = expectation(description: "delete completion")
        ctx.performAndWait {
            deleteSubscribe(context: ctx, entity: row) { ok in
                XCTAssertTrue(ok, "deleteSubscribe must return true on success")
                expDel.fulfill()
            }
        }
        waitForExpectations(timeout: timeoutShort)

        before = countSubscribe(in: ctx) ?? -1
        XCTAssertEqual(before, 0, "Row must be deleted")
    }

    /// subscribeLimit increments below max, and deletes when retryCount >= maxRetryCount.
    func test_4_subscribeLimit_incrementsBelowMax_andDeletesAtLimit() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        // Insert one row
        let expAdd = expectation(description: "add")
        addSubscribeEntity(
            context: ctx,
            userTag: "LIM",
            status: "ok",
            sync: 0,
            profileFields: nil,
            customFields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil,
            uid: "LIM-1"
        ) { expAdd.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        guard let row = fetchAllSubscribe(in: ctx).first else {
            XCTFail("Expected one row"); return
        }

        // Case 1: below max -> increments and returns false
        ctx.performAndWait {
            row.retryCount = 3
            row.maxRetryCount = 5
            try? ctx.save()
        }

        let expInc = expectation(description: "increment")
        subscribeLimit(context: ctx, for: row) { deleted in
            XCTAssertFalse(deleted, "Must not delete when retryCount < maxRetryCount")
            expInc.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        ctx.performAndWait {
            XCTAssertEqual(row.retryCount, 4, "retryCount must be incremented by 1")
        }

        // Case 2: at limit -> delete and return true
        ctx.performAndWait {
            row.retryCount = row.maxRetryCount // equals -> should delete
            try? ctx.save()
        }

        let expDel = expectation(description: "delete at limit")
        subscribeLimit(context: ctx, for: row) { deleted in
            XCTAssertTrue(deleted, "Must delete when retryCount >= maxRetryCount")
            expDel.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let remaining = countSubscribe(in: ctx) ?? -1
        XCTAssertEqual(remaining, 0, "Entity must be deleted at limit")
    }
}

