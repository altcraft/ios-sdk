//
//  PushEventDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushEventDbQueriesTests
 *
 * Positive scenarios:
 *  - test_1: Add push event entity persists fields and returns ID.
 *  - test_2: Get all push events orders by time ascending.
 *  - test_3: Get all push events returns empty when no rows.
 *  - test_4: Clear old push events no-op below or equal threshold.
 *  - test_5: Clear old push events deletes oldest when over threshold.
 */
final class PushEventDbQueriesTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private var sdkContainer: NSPersistentContainer {
        CoreDataManager.shared.persistentContainer
    }
    private var sdkViewContext: NSManagedObjectContext {
        sdkContainer.viewContext
    }

    private func sdkNewBG() -> NSManagedObjectContext {
        let ctx = sdkContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        ctx.undoManager = nil
        return ctx
    }

    private let timeoutShort: TimeInterval = 2.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipe([Constants.EntityNames.pushEvent])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.pushEvent])
        try super.tearDownWithError()
    }

    private func sdkWipe(_ entityNames: [String]) {
        let bg = sdkNewBG()
        bg.performAndWait {
            for name in entityNames {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                fr.includesPropertyValues = false
                if let objects = try? bg.fetch(fr) as? [NSManagedObject] {
                    objects.forEach { bg.delete($0) }
                }
            }
            if bg.hasChanges { try? bg.save() }
        }
    }

    private func sdkCount(_ entityName: String) -> Int {
        let ctx = sdkViewContext
        var result = 0
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fr.includesSubentities = true
            result = (try? ctx.count(for: fr)) ?? 0
        }
        return result
    }

    private func fetchAllPushEventsAsc() -> [PushEventEntity] {
        let ctx = sdkViewContext
        var list: [PushEventEntity] = []
        ctx.performAndWait {
            let fr = NSFetchRequest<PushEventEntity>(entityName: Constants.EntityNames.pushEvent)
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? ctx.fetch(fr)) ?? []
        }
        return list
    }

    private func fetchPushEvent(by id: NSManagedObjectID) -> PushEventEntity? {
        let ctx = sdkViewContext
        var obj: PushEventEntity?
        ctx.performAndWait {
            if let e = try? ctx.existingObject(with: id) as? PushEventEntity {
                obj = e
            }
        }
        return obj
    }

    private func seedPushEvents(count n: Int, base: Int64 = 1_000_000) {
        let group = DispatchGroup()
        for i in 0..<n {
            group.enter()
            addPushEventEntity(uid: "u-\(i)", type: "delivered") { _ in group.leave() }
        }
        _ = group.wait(timeout: .now() + timeoutShort)

        let bg = sdkNewBG()
        bg.performAndWait {
            let fr = NSFetchRequest<PushEventEntity>(entityName: Constants.EntityNames.pushEvent)
            if let rows = try? bg.fetch(fr) {
                for (idx, row) in rows.enumerated() {
                    row.time = base + Int64(idx)
                }
                try? bg.save()
            }
        }
    }

    /// test_1: Add push event entity persists fields and returns ID
    func test_1_addPushEventEntity_persistsFields_andReturnsID() {
        let exp = expectation(description: "insert")
        addPushEventEntity(uid: "uid-1", type: "opened") { id in
            XCTAssertNotNil(id)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let all = fetchAllPushEventsAsc()
        XCTAssertEqual(all.count, 1)
        let e = all[0]
        XCTAssertEqual(e.uid, "uid-1")
        XCTAssertEqual(e.type, "opened")
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)
        XCTAssertGreaterThan(e.time, 0)
    }

    /// test_2: Get all push events orders by time ascending
    func test_2_getAllPushEvents_ordersByTimeAscending() {
        seedPushEvents(count: 3, base: 10_000)

        let bg = sdkNewBG()
        let exp = expectation(description: "fetch ids")
        getAllPushEvents(context: bg) { ids in
            let times = ids.compactMap { self.fetchPushEvent(by: $0)?.time }
            let sorted = times.sorted()
            XCTAssertEqual(times, sorted)
            XCTAssertEqual(times.count, 3)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_3: Get all push events returns empty when no rows
    func test_3_getAllPushEvents_returnsEmpty_whenNoRows() {
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 0)
        let bg = sdkNewBG()
        let exp = expectation(description: "fetch empty")
        getAllPushEvents(context: bg) { ids in
            XCTAssertTrue(ids.isEmpty)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_4: Clear old push events no-op below or equal threshold
    func test_4_clearOldPushEvents_noop_belowOrEqualThreshold() {
        seedPushEvents(count: 5, base: 100)
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 5)

        let bg = sdkNewBG()
        let exp = expectation(description: "clear below-equal")
        clearOldPushEvents(context: bg, threshold: 5, purgeCount: 3) {
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 5)
        let remainingTimes = fetchAllPushEventsAsc().map { $0.time }
        XCTAssertEqual(remainingTimes, [100, 101, 102, 103, 104])
    }

    /// test_5: Clear old push events deletes oldest when over threshold
    func test_5_clearOldPushEvents_deletesOldest_whenOverThreshold() {
        seedPushEvents(count: 7, base: 500)
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 7)

        let bg = sdkNewBG()
        let exp = expectation(description: "clear over")
        clearOldPushEvents(context: bg, threshold: 5, purgeCount: 3) {
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 4)
        let remainingTimes = fetchAllPushEventsAsc().map { $0.time }
        XCTAssertEqual(remainingTimes, [503, 504, 505, 506])
    }
}
