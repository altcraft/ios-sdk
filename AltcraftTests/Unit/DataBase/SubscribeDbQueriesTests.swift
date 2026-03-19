//
//  SubscribeDbQueriesTests.swift
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
* SubscribeDbQueriesTests
*
* Positive scenarios:
* - test_1: addSubscribeEntity persists all core fields and optional payloads.
* - test_2: getAllSubscriptionsByTag filters by tag and sorts by time ascending.
* - test_3: getAllSubscriptionsByTag returns empty array for unknown tag.
* - test_4: clearOldSubscriptions does not delete records when below threshold.
* - test_5: clearOldSubscriptions deletes oldest records when above threshold.
*
*/
final class SubscribeDbQueriesTests: IsolatedTestCase {

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
        sdkWipe([
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.configurationEntity
        ])
    }

    override func tearDownWithError() throws {
        sdkWipe([
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.configurationEntity
        ])
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

    private func sdkCount(entityName: String) -> Int {
        let context = sdkViewContext
        var result = 0

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.includesSubentities = true
            result = (try? context.count(for: fetchRequest)) ?? 0
        }

        return result
    }

    private func fetchSubscribe(by objectID: NSManagedObjectID) -> SubscribeEntity? {
        let context = sdkViewContext
        var entity: SubscribeEntity?

        context.performAndWait {
            entity = try? context.existingObject(with: objectID) as? SubscribeEntity
        }

        return entity
    }

    private func existsSubscribeInStore(_ objectID: NSManagedObjectID) -> Bool {
        let context = sdkNewBackgroundContext()
        var exists = false

        context.performAndWait {
            do {
                let object = try context.existingObject(with: objectID)
                exists = !object.isDeleted
            } catch {
                exists = false
            }
        }

        return exists
    }

    private func fetchAllByTag(_ tag: String) -> [SubscribeEntity] {
        let context = sdkViewContext
        var list: [SubscribeEntity] = []

        context.performAndWait {
            let fetchRequest = NSFetchRequest<SubscribeEntity>(
                entityName: Constants.EntityNames.subscribeEntity
            )
            fetchRequest.predicate = NSPredicate(format: "userTag == %@", tag)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? context.fetch(fetchRequest)) ?? []
        }

        return list
    }

    private func jsonData(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    private func decodeAnyMap(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }

    private func decodeCategories(_ data: Data?) -> [[String: Any]]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]]
    }

    /// test_1: addSubscribeEntity persists all core fields and optional payloads
    func test_1_add_subscribe_entity_persists_all_core_fields_and_optional_payloads() async {
        let tag = "user-1"
        let status = "active"
        let sync = 2

        let profileFields = jsonData([
            "name": "John",
            "age": 30
        ])

        let customFields = jsonData([
            "vip": true,
            "tier": "gold"
        ])

        let cats = jsonData([
            ["name": "inbox", "active": true],
            ["name": "promo", "active": true]
        ])

        let result = await addSubscribeEntity(
            userTag: tag,
            status: status,
            sync: sync,
            profileFields: profileFields,
            customFields: customFields,
            cats: cats,
            replace: nil,
            skipTriggers: nil
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("addSubscribeEntity failed: \(error)")
            return
        }

        let rows = fetchAllByTag(tag)
        XCTAssertEqual(rows.count, 1)

        let entity = rows[0]
        XCTAssertEqual(entity.userTag, tag)
        XCTAssertEqual(entity.status, status)
        XCTAssertEqual(entity.sync, Int16(sync))
        XCTAssertNotNil(entity.requestId)
        XCTAssertFalse(entity.requestId?.isEmpty ?? true)
        XCTAssertFalse(entity.replace)
        XCTAssertFalse(entity.skipTriggers)
        XCTAssertEqual(entity.retryCount, 0)
        XCTAssertEqual(entity.maxRetryCount, 15)
        XCTAssertGreaterThan(entity.time, 0)

        XCTAssertNotNil(entity.cats)
        XCTAssertNotNil(entity.profileFields)
        XCTAssertNotNil(entity.customFields)

        let decodedProfile = decodeAnyMap(entity.profileFields)
        let decodedCustom = decodeAnyMap(entity.customFields)
        let decodedCats = decodeCategories(entity.cats)

        XCTAssertEqual(decodedProfile?["name"] as? String, "John")
        XCTAssertEqual(decodedProfile?["age"] as? Int, 30)
        XCTAssertEqual(decodedCustom?["vip"] as? Bool, true)
        XCTAssertEqual(decodedCustom?["tier"] as? String, "gold")
        XCTAssertEqual(decodedCats?.count, 2)
        XCTAssertEqual(decodedCats?.first?["name"] as? String, "inbox")
        XCTAssertEqual(decodedCats?.first?["active"] as? Bool, true)
    }

    /// test_2: getAllSubscriptionsByTag filters by tag and sorts by time ascending
    func test_2_get_all_subscriptions_by_tag_filters_by_tag_and_sorts_by_time_ascending() async {
        let tagA = "tag-A"
        let tagB = "tag-B"

        for index in 0..<3 {
            let result = await addSubscribeEntity(
                userTag: tagA,
                status: "st\(index)",
                sync: index,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addSubscribeEntity failed: \(error)")
                return
            }
        }

        for index in 0..<2 {
            let result = await addSubscribeEntity(
                userTag: tagB,
                status: "st\(index)",
                sync: index,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addSubscribeEntity failed: \(error)")
                return
            }
        }

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllSubscriptionsByTag(
            context: backgroundContext,
            userTag: tagA
        )

        XCTAssertEqual(ids.count, 3, "Should return only tag-A rows")

        let times: [Int64] = ids.compactMap { fetchSubscribe(by: $0)?.time }
        XCTAssertEqual(times.count, 3)

        let sortedTimes = times.sorted()
        XCTAssertEqual(times, sortedTimes, "Returned IDs must be sorted by time ascending")
    }

    /// test_3: getAllSubscriptionsByTag returns empty array for unknown tag
    func test_3_get_all_subscriptions_by_tag_returns_empty_array_for_unknown_tag() async {
        for index in 0..<2 {
            let result = await addSubscribeEntity(
                userTag: "known",
                status: "s\(index)",
                sync: index,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addSubscribeEntity failed: \(error)")
                return
            }
        }

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllSubscriptionsByTag(
            context: backgroundContext,
            userTag: "unknown"
        )

        XCTAssertTrue(ids.isEmpty)
    }

    /// test_4: clearOldSubscriptions does not delete records when below threshold
    func test_4_clear_old_subscriptions_does_not_delete_records_when_below_threshold() async {
        let tag = "cleanup-tag"

        for index in 0..<3 {
            let result = await addSubscribeEntity(
                userTag: tag,
                status: "st\(index)",
                sync: index,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addSubscribeEntity failed: \(error)")
                return
            }
        }

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.subscribeEntity),
            3,
            "Precondition: we must have exactly 3 records"
        )

        let backgroundContext = sdkNewBackgroundContext()

        await clearOldSubscriptions(
            context: backgroundContext,
            threshold: 5,
            purgeCount: 2
        )

        let after = sdkCount(entityName: Constants.EntityNames.subscribeEntity)
        XCTAssertEqual(after, 3, "Records must not be deleted when below or equal threshold")
    }

    /// test_5: clearOldSubscriptions deletes oldest records when above threshold
    func test_5_clear_old_subscriptions_deletes_oldest_records_when_above_threshold() async {
        let tag = "cleanup-tag-2"

        for index in 0..<6 {
            let result = await addSubscribeEntity(
                userTag: tag,
                status: "st\(index)",
                sync: index,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addSubscribeEntity failed: \(error)")
                return
            }
        }

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.subscribeEntity),
            6,
            "Precondition: we must have exactly 6 records"
        )

        let before = fetchAllByTag(tag)
        XCTAssertEqual(before.count, 6, "Expected 6 records for tag \(tag)")

        let oldestIDs = before.prefix(2).map { $0.objectID }
        let newestIDs = before.suffix(4).map { $0.objectID }

        let backgroundContext = sdkNewBackgroundContext()

        await clearOldSubscriptions(
            context: backgroundContext,
            threshold: 3,
            purgeCount: 2
        )

        let totalAfter = sdkCount(entityName: Constants.EntityNames.subscribeEntity)
        XCTAssertEqual(
            totalAfter,
            4,
            "After purging 2 of 6 records, total must be 4"
        )

        oldestIDs.forEach { objectID in
            let exists = existsSubscribeInStore(objectID)
            XCTAssertFalse(exists, "Oldest record with id \(objectID) must be deleted")
        }

        newestIDs.forEach { objectID in
            let exists = existsSubscribeInStore(objectID)
            XCTAssertTrue(exists, "Newest record with id \(objectID) must stay")
        }
    }
}
