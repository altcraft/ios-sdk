//
//  ProfileUpdateDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
* ProfileUpdateDbQueriesTests
*
* Positive scenarios:
* - test_1: addProfileUpdateEntity inserts record with correct defaults and parameters.
* - test_2: getAllProfileUpdatesByTag filters by userTag and sorts by time ascending.
* - test_3: clearOldProfileUpdates does nothing when total is not over threshold.
* - test_4: clearOldProfileUpdates purges oldest records when total exceeds threshold.
*
*/
final class ProfileUpdateDbQueriesTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override func setUpWithError() throws {
        try super.setUpWithError()
        wipeSDK([Constants.EntityNames.profileUpdateEntity])
        StoredVariablesManager.shared.setGroupsName(value: "AltcraftTests.ProfileUpdate.\(UUID().uuidString)")
        StoredVariablesManager.shared.setCritDB(value: false)
    }

    override func tearDownWithError() throws {
        wipeSDK([Constants.EntityNames.profileUpdateEntity])
        try super.tearDownWithError()
    }

    private func withBackgroundContext(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBGContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.performAndWait {
            block(context)
        }
    }

    private func wipeSDK(_ entityNames: [String]) {
        withBackgroundContext { context in
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

    private func count(_ entityName: String) -> Int {
        var result = 0

        withBackgroundContext { context in
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            result = (try? context.count(for: fetchRequest)) ?? 0
        }

        return result
    }

    private func jsonData(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// test_1: addProfileUpdateEntity inserts record with correct defaults and parameters
    func test_1_add_profile_update_entity_inserts_record_with_correct_defaults_and_parameters() async {
        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 0)

        let profileFields = jsonData([
            "email": "a@b.com",
            "age": 42
        ])

        let result = await addProfileUpdateEntity(
            userTag: "u1",
            profileFields: profileFields,
            skipTriggers: true,
            maxRetryCount: 7
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got error: \(error)")
            return
        }

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 1)

        withBackgroundContext { context in
            let request: NSFetchRequest<ProfileUpdateEntity> = ProfileUpdateEntity.fetchRequest()
            request.fetchLimit = 1
            let list = (try? context.fetch(request)) ?? []

            XCTAssertEqual(list.count, 1)

            let entity = list[0]
            XCTAssertEqual(entity.userTag, "u1")
            XCTAssertNotNil(entity.requestId)
            XCTAssertFalse((entity.requestId ?? "").isEmpty)
            XCTAssertTrue(entity.time > 0)
            XCTAssertEqual(entity.skipTriggers, true)
            XCTAssertEqual(entity.retryCount, 0)
            XCTAssertEqual(entity.maxRetryCount, 7)
            XCTAssertNotNil(entity.profileFields)
            XCTAssertFalse(entity.profileFields?.isEmpty ?? true)
        }
    }

    /// test_2: getAllProfileUpdatesByTag filters by userTag and sorts by time ascending
    func test_2_get_all_profile_updates_by_tag_filters_by_user_tag_and_sorts_by_time_ascending() async {
        withBackgroundContext { context in
            let times: [Int64] = [
                1_700_000_000_002,
                1_700_000_000_000,
                1_700_000_000_001
            ]

            for index in 0..<3 {
                let entity = ProfileUpdateEntity(context: context)
                entity.userTag = "u1"
                entity.requestId = "u1-\(index)"
                entity.time = times[index]
                entity.profileFields = Data("{\"i\":\(index)}".utf8)
                entity.skipTriggers = false
                entity.retryCount = 0
                entity.maxRetryCount = 15
            }

            for index in 0..<2 {
                let entity = ProfileUpdateEntity(context: context)
                entity.userTag = "u2"
                entity.requestId = "u2-\(index)"
                entity.time = Int64(1_700_000_010_000 + index)
                entity.profileFields = Data("{\"x\":\(index)}".utf8)
                entity.skipTriggers = true
                entity.retryCount = 0
                entity.maxRetryCount = 15
            }

            try? context.save()
        }

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 5)

        let fetched: [NSManagedObjectID] = await {
            let context = newBGContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            return await getAllProfileUpdatesByTag(context: context, userTag: "u1")
        }()

        XCTAssertEqual(fetched.count, 3)

        withBackgroundContext { context in
            let objects: [ProfileUpdateEntity] = fetched.compactMap { objectID in
                (try? context.existingObject(with: objectID)) as? ProfileUpdateEntity
            }

            XCTAssertEqual(objects.count, 3)
            XCTAssertTrue(objects.allSatisfy { $0.userTag == "u1" })

            let fetchedTimes = objects.map { $0.time }
            XCTAssertEqual(fetchedTimes, fetchedTimes.sorted())
        }
    }

    /// test_3: clearOldProfileUpdates does nothing when total is not over threshold
    func test_3_clear_old_profile_updates_does_nothing_when_total_is_not_over_threshold() async {
        withBackgroundContext { context in
            for index in 0..<5 {
                let entity = ProfileUpdateEntity(context: context)
                entity.userTag = "u"
                entity.requestId = "rid-\(index)"
                entity.time = Int64(1_700_000_000_000 + index)
                entity.profileFields = Data("{\"i\":\(index)}".utf8)
                entity.skipTriggers = false
                entity.retryCount = 0
                entity.maxRetryCount = 15
            }
            try? context.save()
        }

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 5)

        let context = newBGContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        await clearOldProfileUpdates(
            context: context,
            threshold: 5,
            purgeCount: 2
        )

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 5)
    }

    /// test_4: clearOldProfileUpdates purges oldest records when total exceeds threshold
    func test_4_clear_old_profile_updates_purges_oldest_records_when_total_exceeds_threshold() async {
        withBackgroundContext { context in
            for index in 0..<6 {
                let entity = ProfileUpdateEntity(context: context)
                entity.userTag = "u"
                entity.requestId = "rid-\(index)"
                entity.time = Int64(1_700_000_000_000 + index)
                entity.profileFields = Data("{\"i\":\(index)}".utf8)
                entity.skipTriggers = false
                entity.retryCount = 0
                entity.maxRetryCount = 15
            }
            try? context.save()
        }

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 6)

        let context = newBGContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        await clearOldProfileUpdates(
            context: context,
            threshold: 5,
            purgeCount: 2
        )

        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 4)

        withBackgroundContext { context in
            let request: NSFetchRequest<ProfileUpdateEntity> = ProfileUpdateEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            let list = (try? context.fetch(request)) ?? []

            XCTAssertEqual(list.count, 4)

            let times = list.map { $0.time }
            XCTAssertEqual(times, [
                Int64(1_700_000_000_002),
                Int64(1_700_000_000_003),
                Int64(1_700_000_000_004),
                Int64(1_700_000_000_005)
            ])
        }
    }
}
