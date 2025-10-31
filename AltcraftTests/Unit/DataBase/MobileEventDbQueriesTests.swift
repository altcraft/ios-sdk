//
//  MobileEventDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * MobileEventDbQueriesTests
 *
 * Positive scenarios:
 *  - test_1: addMobileEventEntity saves required fields and encodes optional maps; returns .success.
 *  - test_2: getAllMobileEventsByTag returns only matching userTag and is sorted by increasing time.
 *  - test_3: getAllMobileEventsByTag returns an empty list when no records match the tag.
 *  - test_4: clearOldMobileEvents keeps all rows when total <= threshold.
 *  - test_5: clearOldMobileEvents deletes the oldest N rows when total exceeds threshold.
 */

final class MobileEventDbQueriesTests: IsolatedTestCase {

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
        sdkWipe([Constants.EntityNames.mobileEvent])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.mobileEvent])
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

    private func fetchAllMobileByTagAsc(_ tag: String) -> [MobileEventEntity] {
        let ctx = sdkViewContext
        var list: [MobileEventEntity] = []
        ctx.performAndWait {
            let fr = NSFetchRequest<MobileEventEntity>(entityName: Constants.EntityNames.mobileEvent)
            fr.predicate = NSPredicate(format: "userTag == %@", tag)
            fr.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? ctx.fetch(fr)) ?? []
        }
        return list
    }

    private func fetchMobile(by id: NSManagedObjectID) -> MobileEventEntity? {
        let ctx = sdkViewContext
        var obj: MobileEventEntity?
        ctx.performAndWait {
            if let e = try? ctx.existingObject(with: id) as? MobileEventEntity {
                obj = e
            }
        }
        return obj
    }

    private func decodeAnyMap(_ data: Data?) -> [String: Any]? {
        guard let d = data else { return nil }
        return (try? JSONSerialization.jsonObject(with: d, options: [])) as? [String: Any]
    }

    private func seedMobileEvents(tag: String, count n: Int, base: Int64 = 1_000_000) {
        let group = DispatchGroup()
        for i in 0..<n {
            group.enter()
            addMobileEventEntity(
                userTag: tag,
                timeZone: 0,
                sid: "s-\(i)",
                eventName: "e-\(i)",
                altcraftClientID: "cid",
                payload: nil,
                matching: nil,
                profileFields: nil,
                subscription: nil,
                sendMessageId: nil,
                matchingType: nil,
                utmTags: nil
            ) { _ in group.leave() }
        }
        _ = group.wait(timeout: .now() + timeoutShort)

        let bg = sdkNewBG()
        bg.performAndWait {
            let fr = NSFetchRequest<MobileEventEntity>(entityName: Constants.EntityNames.mobileEvent)
            fr.predicate = NSPredicate(format: "userTag == %@", tag)
            if let rows = try? bg.fetch(fr) {
                for (idx, row) in rows.enumerated() {
                    row.time = base + Int64(idx)
                }
                try? bg.save()
            }
        }
    }

    /// test_1: addMobileEventEntity saves required fields and encodes optional maps; returns .success
    func test_1_addMobileEventEntity_persistsCore_andOptionals() {
        let tag = "user-1"
        let payload: [String: Any?] = ["p1": "v1", "n": 42]
        let matching: [String: Any?] = ["m": true]
        let profile: [String: Any?] = ["name": "John"]

        let exp = expectation(description: "insert")
        addMobileEventEntity(
            userTag: tag,
            timeZone: -180,
            sid: "sid-1",
            eventName: "opened",
            altcraftClientID: "client-1",
            payload: payload,
            matching: matching,
            profileFields: profile,
            subscription: nil,
            sendMessageId: "smid-1",
            matchingType: "push_sub",
            utmTags: nil
        ) { result in
            switch result {
            case .success: exp.fulfill()
            case .failure(let e): XCTFail("addMobileEventEntity failed: \(e)")
            }
        }
        waitForExpectations(timeout: timeoutShort)

        let rows = fetchAllMobileByTagAsc(tag)
        XCTAssertEqual(rows.count, 1)
        let e = rows[0]

        XCTAssertEqual(e.userTag, tag)
        XCTAssertEqual(e.timeZone, -180)
        XCTAssertEqual(e.sid, "sid-1")
        XCTAssertEqual(e.eventName, "opened")
        XCTAssertEqual(e.altcraftClientID, "client-1")
        XCTAssertEqual(e.sendMessageId, "smid-1")
        XCTAssertEqual(e.matchingType, "push_sub")
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)
        XCTAssertGreaterThan(e.time, 0)

        let decPayload = decodeAnyMap(e.payload)
        let decMatching = decodeAnyMap(e.matching)
        let decProfile = decodeAnyMap(e.profileFields)
        XCTAssertEqual(decPayload?["p1"] as? String, "v1")
        XCTAssertEqual(decPayload?["n"] as? Int, 42)
        XCTAssertEqual(decMatching?["m"] as? Bool, true)
        XCTAssertEqual(decProfile?["name"] as? String, "John")
    }

    /// test_2: getAllMobileEventsByTag returns only matching userTag and is sorted by increasing time
    func test_2_getAllMobileEventsByTag_filtersAndSortsByTimeAsc() {
        seedMobileEvents(tag: "A", count: 3, base: 10_000)
        seedMobileEvents(tag: "B", count: 2, base: 20_000)

        let bg = sdkNewBG()
        let exp = expectation(description: "fetch ids by tag A")
        getAllMobileEventsByTag(context: bg, userTag: "A") { ids in
            let times = ids.compactMap { self.fetchMobile(by: $0)?.time }
            let sorted = times.sorted()
            XCTAssertEqual(times, sorted)
            XCTAssertEqual(times.count, 3)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_3: getAllMobileEventsByTag returns an empty list when no records match the tag
    func test_3_getAllMobileEventsByTag_returnsEmpty_forUnknownTag() {
        seedMobileEvents(tag: "known", count: 2, base: 1_000)
        let bg = sdkNewBG()
        let exp = expectation(description: "fetch unknown tag")
        getAllMobileEventsByTag(context: bg, userTag: "unknown") { ids in
            XCTAssertTrue(ids.isEmpty)
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_4: clearOldMobileEvents keeps all rows when total <= threshold
    func test_4_clearOldMobileEvents_noop_belowThreshold() {
        seedMobileEvents(tag: "keep", count: 5, base: 100)
        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 5)

        let bg = sdkNewBG()
        let exp = expectation(description: "clear below")
        clearOldMobileEvents(context: bg, threshold: 10, purgeCount: 3) {
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 5)
        let remaining = fetchAllMobileByTagAsc("keep").map { $0.time }
        XCTAssertEqual(remaining, [100, 101, 102, 103, 104])
    }

    /// test_5: clearOldMobileEvents deletes the oldest N rows when total exceeds threshold
    func test_5_clearOldMobileEvents_deletesOldest_whenOverThreshold() {
        seedMobileEvents(tag: "purge", count: 7, base: 500)
        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 7)

        let bg = sdkNewBG()
        let exp = expectation(description: "clear over")
        clearOldMobileEvents(context: bg, threshold: 5, purgeCount: 3) {
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 4)
        let remaining = fetchAllMobileByTagAsc("purge").map { $0.time }
        XCTAssertEqual(remaining, [503, 504, 505, 506])
    }
}
