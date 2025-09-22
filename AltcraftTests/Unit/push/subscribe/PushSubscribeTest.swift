//
//  PushSubscribeTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushSubscribeTests (iOS 13 compatible)
 *
 * Coverage (concise, explicit names):
 *  - test_1_signAll_allSuccess_deletesAll_and_noRetry
 *  - test_2_signAll_firstRetry_incrementsRetry_and_stops
 *  - test_3_singleSuccess_deletesRow
 *  - test_4_retryAtLimit_deletesAndContinues
 *
 * Notes:
 *  - Uses in-memory Core Data via TestCoreDataStack (production model).
 *  - Network is mocked by overriding sendSubscribeRequest in a test subclass.
 *  - No use of performAndWait (iOS 13 safe). We rely on expectations.
 */
final class PushSubscribeTests: XCTestCase {

    // MARK: - Test Double

    /// Returns canned Events instead of performing real network IO.
    private final class PushSubscribeMock: PushSubscribe {
        var responsesByUID: [String: Event] = [:]

        override func sendSubscribeRequest(entity: SubscribeEntity, completion: @escaping (Event) -> Void) {
            let uid = entity.uid ?? "NO-UID"
            if let ev = responsesByUID[uid] {
                completion(ev)
            } else {
                completion(Event(function: "ok", message: "ok", eventCode: 200))
            }
        }
    }

    // MARK: - Props

    private var stack: TestCoreDataStack!
    private var ctx: NSManagedObjectContext!
    private var sut: PushSubscribeMock!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack(bundleToken: CoreDataManager.self, bundleIdentifier: Constants.CoreData.identifier)
        ctx = stack.newBGContext()
        sut = PushSubscribeMock()
        wipeAll()
    }

    override func tearDown() {
        wipeAll()
        sut = nil
        ctx = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Best-effort cleanup for SubscribeEntity (iOS 13 + in-memory compatible).
    private func wipeAll() {
        let exp = expectation(description: "wipe")
        ctx.perform {
            let fr: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
            fr.includesPropertyValues = false
            fr.includesPendingChanges = true
            do {
                let rows = try self.ctx.fetch(fr)
                rows.forEach { self.ctx.delete($0) }
                try self.ctx.save()
            } catch {
                // ignore in tests
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    /// Async insert helper.
    private func insert(uid: String,
                        userTag: String = "TAG",
                        status: String = "active",
                        sync: Int16 = 0,
                        retry: Int16 = 0,
                        maxRetry: Int16 = 15) {
        let exp = expectation(description: "insert \(uid)")
        ctx.perform {
            let e = SubscribeEntity(context: self.ctx)
            e.uid = uid
            e.userTag = userTag
            e.status = status
            e.sync = sync
            e.time = Int64(Date().timeIntervalSince1970)
            e.retryCount = retry
            e.maxRetryCount = maxRetry
            e.replace = false
            e.skipTriggers = false
            e.cats = nil
            e.profileFields = nil
            e.customFields = nil
            _ = try? self.ctx.save()
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    /// Fetch all (async → sync via expectation).
    private func fetchAll() -> [SubscribeEntity] {
        var out: [SubscribeEntity] = []
        let exp = expectation(description: "fetch")
        ctx.perform {
            let fr: NSFetchRequest<SubscribeEntity> = SubscribeEntity.fetchRequest()
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            out = (try? self.ctx.fetch(fr)) ?? []
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        return out
    }

    /// Read a specific entity (if still exists).
    private func read(objectID: NSManagedObjectID) -> SubscribeEntity? {
        var obj: SubscribeEntity?
        let exp = expectation(description: "read")
        ctx.perform {
            obj = try? self.ctx.existingObject(with: objectID) as? SubscribeEntity
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        return obj
    }

    // MARK: - Tests

    /// All sends succeed → all rows deleted, no retry.
    func test_1_signAll_allSuccess_deletesAll_and_noRetry() {
        insert(uid: "A")
        insert(uid: "B")
        insert(uid: "C")

        let exp = expectation(description: "signAll ok")
        sut.signAll(context: ctx, subscriptions: fetchAll()) { retry in
            XCTAssertFalse(retry)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(fetchAll().count, 0)
    }

    /// First returns RetryEvent → retryCount +1 and processing stops (retry=true).
    func test_2_signAll_firstRetry_incrementsRetry_and_stops() {
        insert(uid: "FIRST", retry: 0, maxRetry: 5)
        insert(uid: "SECOND")
        insert(uid: "THIRD")

        // canned retry on FIRST
        sut.responsesByUID["FIRST"] = RetryEvent(function: "retry", message: "retry", eventCode: 500)

        // Build deterministic order: FIRST, then SECOND, then THIRD.
        let all = fetchAll()
        let first  = all.first { $0.uid == "FIRST" }!
        let second = all.first { $0.uid == "SECOND" }!
        let third  = all.first { $0.uid == "THIRD" }!
        let firstID = first.objectID

        let exp = expectation(description: "stop on retry")
        sut.signAll(context: ctx, subscriptions: [first, second, third]) { retry in
            XCTAssertTrue(retry)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        // retryCount incremented on FIRST
        let updated = read(objectID: firstID)
        XCTAssertEqual(updated?.retryCount, 1)

        // Nothing deleted, as processing stopped after FIRST retry.
        XCTAssertEqual(fetchAll().count, 3)
    }

    /// Single success deletes the row.
    func test_3_singleSuccess_deletesRow() {
        insert(uid: "ONE")
        let ent = fetchAll().first!
        let entID = ent.objectID

        let exp = expectation(description: "single ok")
        sut.signAll(context: ctx, subscriptions: [ent]) { retry in
            XCTAssertFalse(retry)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        XCTAssertNil(read(objectID: entID))
        XCTAssertEqual(fetchAll().count, 0)
    }

    /// Retry at limit → entity deleted; next succeeds; overall no retry.
    func test_4_retryAtLimit_deletesAndContinues() {
        insert(uid: "LIMIT", retry: 3, maxRetry: 3) // at limit
        insert(uid: "OK")

        sut.responsesByUID["LIMIT"] = RetryEvent(function: "retry", message: "retry", eventCode: 500)

        let all = fetchAll()
        let limitID = all.first(where: { $0.uid == "LIMIT" })!.objectID
        let okID    = all.first(where: { $0.uid == "OK" })!.objectID

        let exp = expectation(description: "limit path")
        sut.signAll(context: ctx, subscriptions: all) { retry in
            XCTAssertFalse(retry)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        XCTAssertNil(read(objectID: limitID)) // deleted at limit
        XCTAssertNil(read(objectID: okID))    // deleted on success
        XCTAssertEqual(fetchAll().count, 0)
    }
}


