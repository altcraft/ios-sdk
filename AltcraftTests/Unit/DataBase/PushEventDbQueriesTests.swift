//
//  PushEventDbQueriesTests.swift
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
* PushEventDbQueriesTests
*
* Positive scenarios:
* - test_1: addPushEventEntity persists fields and returns object ID.
* - test_2: getAllPushEvents orders results by time ascending.
* - test_3: getAllPushEvents returns empty array when no rows exist.
* - test_4: clearOldPushEvents does not delete rows when count is below or equal to threshold.
* - test_5: clearOldPushEvents deletes oldest rows when count is above threshold.
*
*/
final class PushEventDbQueriesTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private var sdkContainer: NSPersistentContainer {
        CoreDataManager.shared.persistentContainer
    }

    private var sdkViewContext: NSManagedObjectContext {
        sdkContainer.viewContext
    }

    private func sdkNewBackgroundContext() -> NSManagedObjectContext {
        let context = sdkContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        return context
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipe([Constants.EntityNames.pushEventEntity])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.pushEventEntity])
        try super.tearDownWithError()
    }

    private func sdkWipe(_ entityNames: [String]) {
        let context = sdkNewBackgroundContext()

        context.performAndWait {
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.includesPropertyValues = false

                if let objects = try? context.fetch(fetchRequest) as? [NSManagedObject] {
                    objects.forEach { context.delete($0) }
                }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    private func sdkCount(_ entityName: String) -> Int {
        let context = sdkViewContext
        var result = 0

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.includesSubentities = true
            result = (try? context.count(for: fetchRequest)) ?? 0
        }

        return result
    }

    private func fetchAllPushEventsAscending() -> [PushEventEntity] {
        let context = sdkViewContext
        var list: [PushEventEntity] = []

        context.performAndWait {
            let fetchRequest = NSFetchRequest<PushEventEntity>(
                entityName: Constants.EntityNames.pushEventEntity
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? context.fetch(fetchRequest)) ?? []
        }

        return list
    }

    private func fetchPushEvent(by objectID: NSManagedObjectID) -> PushEventEntity? {
        let context = sdkViewContext
        var entity: PushEventEntity?

        context.performAndWait {
            entity = try? context.existingObject(with: objectID) as? PushEventEntity
        }

        return entity
    }

    private func seedPushEvents(count: Int, base: Int64 = 1_000_000) async {
        for index in 0..<count {
            let objectID = await addPushEventEntity(
                uid: "u-\(index)",
                type: "delivered"
            )
            XCTAssertNotNil(objectID)
        }

        let context = sdkNewBackgroundContext()

        context.performAndWait {
            let fetchRequest = NSFetchRequest<PushEventEntity>(
                entityName: Constants.EntityNames.pushEventEntity
            )

            if let rows = try? context.fetch(fetchRequest) {
                for (index, row) in rows.enumerated() {
                    row.time = base + Int64(index)
                }
                try? context.save()
            }
        }
    }

    /// test_1: addPushEventEntity persists fields and returns object ID
    func test_1_add_push_event_entity_persists_fields_and_returns_object_id() async {
        let objectID = await addPushEventEntity(
            uid: "uid-1",
            type: "opened"
        )

        XCTAssertNotNil(objectID)

        let all = fetchAllPushEventsAscending()
        XCTAssertEqual(all.count, 1)

        let entity = all[0]
        XCTAssertEqual(entity.uid, "uid-1")
        XCTAssertEqual(entity.type, "opened")
        XCTAssertEqual(entity.retryCount, 0)
        XCTAssertEqual(entity.maxRetryCount, 15)
        XCTAssertGreaterThan(entity.time, 0)
        XCTAssertNotNil(entity.requestId)
        XCTAssertFalse(entity.requestId?.isEmpty ?? true)
    }

    /// test_2: getAllPushEvents orders results by time ascending
    func test_2_get_all_push_events_orders_results_by_time_ascending() async {
        await seedPushEvents(count: 3, base: 10_000)

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllPushEvents(context: backgroundContext)

        let times = ids.compactMap { fetchPushEvent(by: $0)?.time }
        let sortedTimes = times.sorted()

        XCTAssertEqual(times, sortedTimes)
        XCTAssertEqual(times.count, 3)
    }

    /// test_3: getAllPushEvents returns empty array when no rows exist
    func test_3_get_all_push_events_returns_empty_array_when_no_rows_exist() async {
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 0)

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllPushEvents(context: backgroundContext)

        XCTAssertTrue(ids.isEmpty)
    }

    /// test_4: clearOldPushEvents does not delete rows when count is below or equal to threshold
    func test_4_clear_old_push_events_does_not_delete_rows_when_count_is_below_or_equal_to_threshold() async {
        await seedPushEvents(count: 5, base: 100)

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 5)

        let backgroundContext = sdkNewBackgroundContext()
        await clearOldPushEvents(
            context: backgroundContext,
            threshold: 5,
            purgeCount: 3
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 5)

        let remainingTimes = fetchAllPushEventsAscending().map { $0.time }
        XCTAssertEqual(remainingTimes, [100, 101, 102, 103, 104])
    }

    /// test_5: clearOldPushEvents deletes oldest rows when count is above threshold
    func test_5_clear_old_push_events_deletes_oldest_rows_when_count_is_above_threshold() async {
        await seedPushEvents(count: 7, base: 500)

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 7)

        let before = fetchAllPushEventsAscending()
        XCTAssertEqual(before.count, 7)

        let oldestIDs = Set(before.prefix(3).map(\.objectID))

        let backgroundContext = sdkNewBackgroundContext()
        await clearOldPushEvents(
            context: backgroundContext,
            threshold: 5,
            purgeCount: 3
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 4)

        let remaining = fetchAllPushEventsAscending()
        let remainingTimes = remaining.map(\.time)
        XCTAssertEqual(remainingTimes, [503, 504, 505, 506])

        let remainingIDs = Set(remaining.map(\.objectID))
        XCTAssertTrue(oldestIDs.isDisjoint(with: remainingIDs))
    }
}
