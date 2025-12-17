//
//  SubscribeDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * SubscribeDbQueriesTests
 *
 * Positive scenarios:
 *  - test_1: Add subscribe entity persists all core fields and optionals.
 *  - test_2: Get all subscriptions by tag filters and sorts by time ascending.
 *  - test_3: Get all subscriptions by tag returns empty for unknown tag.
 *  - test_4: clearOldSubscriptions does not delete records when below threshold.
 *  - test_5: clearOldSubscriptions deletes oldest records when above threshold.
 */
final class SubscribeDbQueriesTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private var sdkContainer: NSPersistentContainer { CoreDataManager.shared.persistentContainer }
    private var sdkViewContext: NSManagedObjectContext { sdkContainer.viewContext }

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
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
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

    private func sdkCount(entityName: String) -> Int {
        let ctx = sdkViewContext
        var result = 0
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fr.includesSubentities = true
            result = (try? ctx.count(for: fr)) ?? 0
        }
        return result
    }

    private func fetchSubscribe(by id: NSManagedObjectID) -> SubscribeEntity? {
        let ctx = sdkViewContext
        var out: SubscribeEntity?
        ctx.performAndWait {
            if let obj = try? ctx.existingObject(with: id) as? SubscribeEntity {
                out = obj
            }
        }
        return out
    }

    /// Проверяет наличие SubscribeEntity в сторе, минуя кеш viewContext.
    /// Используем новый background context, чтобы видеть реальные данные в persistent store.
    private func existsSubscribeInStore(_ id: NSManagedObjectID) -> Bool {
        let ctx = sdkNewBG()
        var exists = false
        ctx.performAndWait {
            do {
                let obj = try ctx.existingObject(with: id)
                exists = !obj.isDeleted
            } catch {
                exists = false
            }
        }
        return exists
    }

    private func fetchAllByTag(_ tag: String) -> [SubscribeEntity] {
        let ctx = sdkViewContext
        var list: [SubscribeEntity] = []
        ctx.performAndWait {
            let fr = NSFetchRequest<SubscribeEntity>(entityName: Constants.EntityNames.subscribe)
            fr.predicate = NSPredicate(format: "userTag == %@", tag)
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? ctx.fetch(fr)) ?? []
        }
        return list
    }

    private func decodeAnyMap(_ data: Data?) -> [String: Any]? {
        guard let d = data else { return nil }
        return (try? JSONSerialization.jsonObject(with: d, options: [])) as? [String: Any]
    }

    /// test_1: Add subscribe entity persists all core fields and optionals
    func test_1_addSubscribeEntity_persistsAllCoreFields_andOptionals() {
        let tag = "user-1"
        let status = "active"
        let sync = 2
        let profile: [String: Any?] = ["name": "John", "age": 30]
        let custom:  [String: Any?] = ["vip": true, "tier": "gold"]
        let cats: [CategoryData] = [
            CategoryData(name: "inbox", active: true),
            CategoryData(name: "promo", active: true)
        ]

        let exp = expectation(description: "add entity")
        addSubscribeEntity(
            userTag: tag,
            status: status,
            sync: sync,
            profileFields: profile,
            customFields: custom,
            cats: cats,
            replace: nil,
            skipTriggers: nil,
            uid: "req-1"
        ) { result in
            switch result {
            case .success: exp.fulfill()
            case .failure(let e): XCTFail("addSubscribeEntity failed: \(e)")
            }
        }
        waitForExpectations(timeout: timeoutShort)

        let rows = fetchAllByTag(tag)
        XCTAssertEqual(rows.count, 1)
        let e = rows[0]

        XCTAssertEqual(e.userTag, tag)
        XCTAssertEqual(e.status, status)
        XCTAssertEqual(e.sync, Int16(sync))
        XCTAssertEqual(e.uid, "req-1")
        XCTAssertFalse(e.replace)
        XCTAssertFalse(e.skipTriggers)
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)
        XCTAssertGreaterThan(e.time, 0)

        XCTAssertNotNil(e.cats)
        XCTAssertNotNil(e.profileFields)
        XCTAssertNotNil(e.customFields)

        let decodedProfile = decodeAnyMap(e.profileFields)
        let decodedCustom  = decodeAnyMap(e.customFields)
        XCTAssertEqual(decodedProfile?["name"] as? String, "John")
        XCTAssertEqual(decodedProfile?["age"] as? Int, 30)
        XCTAssertEqual(decodedCustom?["vip"] as? Bool, true)
        XCTAssertEqual(decodedCustom?["tier"] as? String, "gold")
    }

    /// test_2: Get all subscriptions by tag filters and sorts by time ascending
    func test_2_getAllSubscriptionsByTag_filtersAndSortsByTimeAsc() {
        let tagA = "tag-A"
        let tagB = "tag-B"
        let group = DispatchGroup()

        for i in 0..<3 {
            group.enter()
            addSubscribeEntity(
                userTag: tagA, status: "st\(i)", sync: i,
                profileFields: nil, customFields: nil, cats: nil,
                replace: false, skipTriggers: false, uid: "A\(i)"
            ) { _ in group.leave() }
        }

        for i in 0..<2 {
            group.enter()
            addSubscribeEntity(
                userTag: tagB, status: "st\(i)", sync: i,
                profileFields: nil, customFields: nil, cats: nil,
                replace: false, skipTriggers: false, uid: "B\(i)"
            ) { _ in group.leave() }
        }

        let waitOk = group.wait(timeout: .now() + timeoutShort)
        XCTAssertEqual(waitOk, .success, "addSubscribeEntity timed out")

        let bg = sdkNewBG()
        let exp = expectation(description: "fetch by tag A")
        getAllSubscriptionsByTag(context: bg, userTag: tagA) { ids in
            XCTAssertEqual(ids.count, 3, "Should return only tag-A rows")
            let times: [Int64] = ids.compactMap { self.fetchSubscribe(by: $0)?.time }
            let sorted = times.sorted()
            XCTAssertEqual(times, sorted, "Returned IDs must be sorted by time ascending")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_3: Get all subscriptions by tag returns empty for unknown tag
    func test_3_getAllSubscriptionsByTag_returnsEmpty_forUnknownTag() {
        let group = DispatchGroup()
        for i in 0..<2 {
            group.enter()
            addSubscribeEntity(
                userTag: "known", status: "s\(i)", sync: i,
                profileFields: nil, customFields: nil, cats: nil,
                replace: false, skipTriggers: false, uid: "K\(i)"
            ) { _ in group.leave() }
        }
        let ok = group.wait(timeout: .now() + timeoutShort)
        XCTAssertEqual(ok, .success)

        let bg = sdkNewBG()
        let exp = expectation(description: "fetch unknown tag")
        getAllSubscriptionsByTag(context: bg, userTag: "unknown") { ids in
            XCTAssertTrue(ids.isEmpty)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_4: clearOldSubscriptions does not delete records when below threshold
    func test_4_clearOldSubscriptions_doesNotDelete_whenBelowThreshold() {
        let tag = "cleanup-tag"
        let group = DispatchGroup()

        for i in 0..<3 {
            group.enter()
            addSubscribeEntity(
                userTag: tag,
                status: "st\(i)",
                sync: i,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false,
                uid: "C\(i)"
            ) { _ in group.leave() }
        }

        let ok = group.wait(timeout: .now() + timeoutShort)
        XCTAssertEqual(ok, .success, "addSubscribeEntity timed out")

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.subscribe),
            3,
            "Precondition: we must have exactly 3 records"
        )

        let bg = sdkNewBG()
        let exp = expectation(description: "clearOldSubscriptions below threshold")
        clearOldSubscriptions(
            context: bg,
            threshold: 5,
            purgeCount: 2
        ) {
            let after = self.sdkCount(entityName: Constants.EntityNames.subscribe)
            XCTAssertEqual(after, 3, "Records must not be deleted when below or equal threshold")
            exp.fulfill()
        }

        waitForExpectations(timeout: timeoutShort)
    }

    /// test_5: clearOldSubscriptions deletes oldest records when above threshold
    func test_5_clearOldSubscriptions_deletesOldest_whenAboveThreshold() {
        let tag = "cleanup-tag-2"
        let group = DispatchGroup()
        
        for i in 0..<6 {
            group.enter()
            addSubscribeEntity(
                userTag: tag,
                status: "st\(i)",
                sync: i,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false,
                uid: "D\(i)"
            ) { _ in group.leave() }
        }

        let ok = group.wait(timeout: .now() + timeoutShort)
        XCTAssertEqual(ok, .success, "addSubscribeEntity timed out")

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.subscribe),
            6,
            "Precondition: we must have exactly 6 records"
        )

        let before = fetchAllByTag(tag)
        XCTAssertEqual(before.count, 6, "Expected 6 records for tag \(tag)")

        let oldestIDs = before.prefix(2).map { $0.objectID }
        let newestIDs = before.suffix(4).map { $0.objectID }

        let bg = sdkNewBG()
        let exp = expectation(description: "clearOldSubscriptions above threshold")

        clearOldSubscriptions(
            context: bg,
            threshold: 3,
            purgeCount: 2
        ) {
            let totalAfter = self.sdkCount(entityName: Constants.EntityNames.subscribe)
            XCTAssertEqual(
                totalAfter,
                4,
                "After purging 2 of 6 records, total must be 4"
            )

            oldestIDs.forEach { id in
                let exists = self.existsSubscribeInStore(id)
                XCTAssertFalse(exists, "Oldest record with id \(id) must be deleted")
            }
            
            newestIDs.forEach { id in
                let exists = self.existsSubscribeInStore(id)
                XCTAssertTrue(exists, "Newest record with id \(id) must stay")
            }

            exp.fulfill()
        }

        waitForExpectations(timeout: timeoutShort)
    }
}
