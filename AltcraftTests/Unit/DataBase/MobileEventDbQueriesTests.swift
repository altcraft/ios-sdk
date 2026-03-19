//
//  MobileEventDbQueriesTests.swift
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
* MobileEventDbQueriesTests
*
* Positive scenarios:
* - test_1: addMobileEventEntity saves required fields and encoded optional payloads.
* - test_2: getAllMobileEventsByTag returns only matching userTag and is sorted by increasing time.
* - test_3: getAllMobileEventsByTag returns an empty list when no records match the tag.
* - test_4: clearOldMobileEvents keeps all rows when total is below or equal to threshold.
* - test_5: clearOldMobileEvents deletes the oldest rows when total exceeds threshold.
*
*/
final class MobileEventDbQueriesTests: IsolatedTestCase {

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
        sdkWipe([Constants.EntityNames.mobileEventEntity])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.mobileEventEntity])
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

    private func fetchAllMobileByTagAscending(_ tag: String) -> [MobileEventEntity] {
        let context = sdkViewContext
        var list: [MobileEventEntity] = []

        context.performAndWait {
            let fetchRequest = NSFetchRequest<MobileEventEntity>(
                entityName: Constants.EntityNames.mobileEventEntity
            )
            fetchRequest.predicate = NSPredicate(format: "userTag == %@", tag)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? context.fetch(fetchRequest)) ?? []
        }

        return list
    }

    private func fetchMobile(by objectID: NSManagedObjectID) -> MobileEventEntity? {
        let context = sdkViewContext
        var entity: MobileEventEntity?

        context.performAndWait {
            entity = try? context.existingObject(with: objectID) as? MobileEventEntity
        }

        return entity
    }

    private func jsonData(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    private func decodeAnyMap(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
    }

    private func seedMobileEvents(tag: String, count: Int, base: Int64 = 1_000_000) async {
        for index in 0..<count {
            let result = await addMobileEventEntity(
                sid: "s-\(index)",
                userTag: tag,
                timeZone: 0,
                eventName: "e-\(index)",
                payloadData: nil,
                matchingData: nil,
                sendMessageId: nil,
                matchingType: nil,
                utmTagsData: nil,
                altcraftClientID: "cid",
                profileFieldsData: nil,
                subscriptionData: nil
            )

            switch result {
            case .success:
                break
            case .failure(let error):
                XCTFail("addMobileEventEntity failed: \(error)")
                return
            }
        }

        let context = sdkNewBackgroundContext()

        context.performAndWait {
            let fetchRequest = NSFetchRequest<MobileEventEntity>(
                entityName: Constants.EntityNames.mobileEventEntity
            )
            fetchRequest.predicate = NSPredicate(format: "userTag == %@", tag)

            if let rows = try? context.fetch(fetchRequest) {
                for (index, row) in rows.enumerated() {
                    row.time = base + Int64(index)
                }
                try? context.save()
            }
        }
    }

    /// test_1: addMobileEventEntity saves required fields and encoded optional payloads
    func test_1_add_mobile_event_entity_saves_required_fields_and_encoded_optional_payloads() async {
        let tag = "user-1"
        let payloadData = jsonData(["p1": "v1", "n": 42])
        let matchingData = jsonData(["m": true])
        let profileFieldsData = jsonData(["name": "John"])

        let result = await addMobileEventEntity(
            sid: "sid-1",
            userTag: tag,
            timeZone: -180,
            eventName: "opened",
            payloadData: payloadData,
            matchingData: matchingData,
            sendMessageId: "smid-1",
            matchingType: "push_sub",
            utmTagsData: nil,
            altcraftClientID: "client-1",
            profileFieldsData: profileFieldsData,
            subscriptionData: nil
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("addMobileEventEntity failed: \(error)")
            return
        }

        let rows = fetchAllMobileByTagAscending(tag)
        XCTAssertEqual(rows.count, 1)

        let entity = rows[0]
        XCTAssertEqual(entity.userTag, tag)
        XCTAssertEqual(entity.timeZone, -180)
        XCTAssertEqual(entity.sid, "sid-1")
        XCTAssertEqual(entity.eventName, "opened")
        XCTAssertEqual(entity.altcraftClientID, "client-1")
        XCTAssertEqual(entity.sendMessageId, "smid-1")
        XCTAssertEqual(entity.matchingType, "push_sub")
        XCTAssertEqual(entity.retryCount, 0)
        XCTAssertEqual(entity.maxRetryCount, 15)
        XCTAssertGreaterThan(entity.time, 0)
        XCTAssertNotNil(entity.requestId)
        XCTAssertFalse(entity.requestId?.isEmpty ?? true)

        let decodedPayload = decodeAnyMap(entity.payload)
        let decodedMatching = decodeAnyMap(entity.matching)
        let decodedProfile = decodeAnyMap(entity.profileFields)

        XCTAssertEqual(decodedPayload?["p1"] as? String, "v1")
        XCTAssertEqual(decodedPayload?["n"] as? Int, 42)
        XCTAssertEqual(decodedMatching?["m"] as? Bool, true)
        XCTAssertEqual(decodedProfile?["name"] as? String, "John")
    }

    /// test_2: getAllMobileEventsByTag returns only matching userTag and is sorted by increasing time
    func test_2_get_all_mobile_events_by_tag_returns_only_matching_user_tag_and_is_sorted_by_increasing_time() async {
        await seedMobileEvents(tag: "A", count: 3, base: 10_000)
        await seedMobileEvents(tag: "B", count: 2, base: 20_000)

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllMobileEventsByTag(
            context: backgroundContext,
            userTag: "A"
        )

        let times = ids.compactMap { fetchMobile(by: $0)?.time }
        let sortedTimes = times.sorted()

        XCTAssertEqual(times, sortedTimes)
        XCTAssertEqual(times.count, 3)
    }

    /// test_3: getAllMobileEventsByTag returns an empty list when no records match the tag
    func test_3_get_all_mobile_events_by_tag_returns_an_empty_list_when_no_records_match_the_tag() async {
        await seedMobileEvents(tag: "known", count: 2, base: 1_000)

        let backgroundContext = sdkNewBackgroundContext()
        let ids = await getAllMobileEventsByTag(
            context: backgroundContext,
            userTag: "unknown"
        )

        XCTAssertTrue(ids.isEmpty)
    }

    /// test_4: clearOldMobileEvents keeps all rows when total is below or equal to threshold
    func test_4_clear_old_mobile_events_keeps_all_rows_when_total_is_below_or_equal_to_threshold() async {
        await seedMobileEvents(tag: "keep", count: 5, base: 100)

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEventEntity), 5)

        let backgroundContext = sdkNewBackgroundContext()
        await clearOldMobileEvents(
            context: backgroundContext,
            threshold: 10,
            purgeCount: 3
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEventEntity), 5)

        let remainingTimes = fetchAllMobileByTagAscending("keep").map { $0.time }
        XCTAssertEqual(remainingTimes, [100, 101, 102, 103, 104])
    }

    /// test_5: clearOldMobileEvents deletes the oldest rows when total exceeds threshold
    func test_5_clear_old_mobile_events_deletes_the_oldest_rows_when_total_exceeds_threshold() async {
        await seedMobileEvents(tag: "purge", count: 7, base: 500)

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEventEntity), 7)

        let backgroundContext = sdkNewBackgroundContext()
        await clearOldMobileEvents(
            context: backgroundContext,
            threshold: 5,
            purgeCount: 3
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEventEntity), 4)

        let remainingTimes = fetchAllMobileByTagAscending("purge").map { $0.time }
        XCTAssertEqual(remainingTimes, [503, 504, 505, 506])
    }
}
