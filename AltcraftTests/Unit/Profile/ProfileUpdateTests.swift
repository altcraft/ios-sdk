//
//  ProfileUpdateTests.swift
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
 * ProfileUpdateTests
 *
 * Positive scenarios:
 * - test_1: profileUpdateRequest builds valid POST JSON request with Authorization header.
 * - test_2: request with invalid objectID returns RetryEvent when request data cannot be built.
 * - test_3: request with non-buildable payload returns RetryEvent when request cannot be created.
 * - test_4: processUpdate on RetryEvent path increments retryCount and returns true.
 * - test_5: processUpdate on max retry deletes entity and returns false.
 * - test_6: processUpdates stops on the first retrying entity and leaves the next one untouched.
 * - test_7: processUpdates with empty queue returns true.
 * - test_8: retryLimit with invalid objectID returns true when objectID is invalid.
 * - test_9: retryLimit increments retryCount until max, then deletes entity.
 *
 */
final class ProfileUpdateTests: IsolatedTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = CoreDataManager.shared.getContext()
        try wipeUpdates()
    }

    override func tearDownWithError() throws {
        try wipeUpdates()
        context = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeUpdate(
        userTag: String = "user-1",
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        profileFields: [String: Any?]? = ["age": 30, "name": "Ann"],
        skipTriggers: Bool = false,
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2
    ) throws -> NSManagedObjectID {
        var objectID: NSManagedObjectID?

        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: Constants.EntityNames.profileUpdateEntity,
                into: context
            )

            entity.setValue(userTag, forKey: "userTag")
            entity.setValue(UUID().uuidString, forKey: "requestId")
            entity.setValue(time, forKey: "time")
            entity.setValue(encodeAnyMap(profileFields), forKey: "profileFields")
            entity.setValue(skipTriggers, forKey: "skipTriggers")
            entity.setValue(retryCount, forKey: "retryCount")
            entity.setValue(maxRetryCount, forKey: "maxRetryCount")

            do {
                if entity.objectID.isTemporaryID {
                    try context.obtainPermanentIDs(for: [entity])
                }
                try context.save()
                objectID = entity.objectID
            } catch {
                XCTFail("Failed to save ProfileUpdateEntity: \(error)")
            }
        }

        return try XCTUnwrap(objectID)
    }

    private func deleteUpdate(by id: NSManagedObjectID) throws {
        context.performAndWait {
            guard let object = resolveObject(in: context, from: id) else {
                return
            }

            context.delete(object)

            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                XCTFail("Failed to delete ProfileUpdateEntity: \(error)")
            }
        }
    }

    private func fetchUpdate(by id: NSManagedObjectID) throws -> ProfileUpdateEntity? {
        var object: ProfileUpdateEntity?

        context.performAndWait {
            object = resolveObject(in: context, from: id) as? ProfileUpdateEntity
        }

        return object
    }

    private func fetchAllUpdates() throws -> [ProfileUpdateEntity] {
        var objects: [ProfileUpdateEntity] = []

        context.performAndWait {
            let req = NSFetchRequest<ProfileUpdateEntity>(entityName: Constants.EntityNames.profileUpdateEntity)
            objects = (try? context.fetch(req)) ?? []
        }

        return objects
    }

    private func wipeUpdates() throws {
        context.performAndWait {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.profileUpdateEntity)

            if let objects = try? context.fetch(req) as? [NSManagedObject] {
                objects.forEach { context.delete($0) }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    /// test_1: profileUpdateRequest builds valid POST JSON request with Authorization header
    func test_1_profileUpdateRequest_builds_valid_post_json_request_with_auth() throws {
        let data = ProfileUpdateRequestData(
            url: "https://api.altcraft.test/profile",
            requestId: "RID-\(UUID().uuidString)",
            authHeader: "Bearer token",
            profileFields: ["age": 30, "name": "Ann"],
            skipTriggers: true
        )

        let request = profileUpdateRequest(data: data)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(
            request?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization),
            "Bearer token"
        )

        let contentType = request?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(contentType.contains("application/json"))

        XCTAssertNotNil(request?.httpBody)

        if let body = request?.httpBody {
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: body, options: []))
        }
    }

    /// test_2: request with invalid objectID returns RetryEvent when request data cannot be built
    func test_2_request_with_invalid_objectID_returns_retry_event_when_request_data_cannot_be_built() async throws {
        let id = try makeUpdate()
        try deleteUpdate(by: id)

        let event = await ProfileUpdate.shared.test_profile_update_request(
            context: context,
            update: id
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_3: request with non-buildable payload returns RetryEvent when request cannot be created
    func test_3_request_with_non_buildable_payload_returns_retry_event_when_request_cannot_be_created() async throws {
        let id = try makeUpdate(profileFields: ["bad": Date()])

        let event = await ProfileUpdate.shared.test_profile_update_request(
            context: context,
            update: id
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_4: processUpdate on RetryEvent path increments retryCount and returns true
    func test_4_processUpdate_on_retry_event_path_increments_retryCount_and_returns_true() async throws {
        let id = try makeUpdate(
            profileFields: ["bad": Date()],
            retryCount: 0,
            maxRetryCount: 2
        )

        let shouldStopAndRetryLater = await ProfileUpdate.shared.test_profile_update_processUpdate(
            context: context,
            update: id
        )

        XCTAssertTrue(shouldStopAndRetryLater)

        let updated = try XCTUnwrap(fetchUpdate(by: id))
        XCTAssertEqual(updated.retryCount, 1)
        XCTAssertEqual(updated.maxRetryCount, 2)
    }

    /// test_5: processUpdate on max retry deletes entity and returns false
    func test_5_processUpdate_on_max_retry_deletes_entity_and_returns_false() async throws {
        let id = try makeUpdate(
            profileFields: ["bad": Date()],
            retryCount: 0,
            maxRetryCount: 0
        )

        let shouldStopAndRetryLater = await ProfileUpdate.shared.test_profile_update_processUpdate(
            context: context,
            update: id
        )

        XCTAssertFalse(shouldStopAndRetryLater)
        XCTAssertNil(try fetchUpdate(by: id))
    }

    /// test_6: processUpdates stops on the first retrying entity and leaves the next one untouched
    func test_6_processUpdates_stops_on_the_first_retrying_entity_and_leaves_the_next_one_untouched() async throws {
        let tag = "user-stop-chain-\(UUID().uuidString)"

        let firstID = try makeUpdate(
            userTag: tag,
            time: 1,
            profileFields: ["bad": Date()],
            retryCount: 0,
            maxRetryCount: 2
        )

        let secondID = try makeUpdate(
            userTag: tag,
            time: 2,
            profileFields: ["age": 30, "name": "Ann"],
            retryCount: 0,
            maxRetryCount: 2
        )

        let result = await ProfileUpdate.shared.test_profile_update_processUpdates(
            userTag: tag
        )

        XCTAssertFalse(result)

        let firstUpdated = try XCTUnwrap(fetchUpdate(by: firstID))
        XCTAssertEqual(firstUpdated.retryCount, 1)

        let secondUpdated = try XCTUnwrap(fetchUpdate(by: secondID))
        XCTAssertEqual(secondUpdated.retryCount, 0)
    }

    /// test_7: processUpdates with empty queue returns true
    func test_7_processUpdates_with_empty_queue_returns_true() async {
        let result = await ProfileUpdate.shared.test_profile_update_processUpdates(
            userTag: "missing-\(UUID().uuidString)"
        )

        XCTAssertTrue(result)
    }

    /// test_8: retryLimit with invalid objectID returns true when objectID is invalid
    func test_8_retryLimit_with_invalid_objectID_returns_true_when_objectID_is_invalid() async throws {
        let id = try makeUpdate()
        try deleteUpdate(by: id)

        let deleted = await retryLimit(
            context: context,
            objectID: id
        )

        XCTAssertTrue(deleted)
    }

    /// test_9: retryLimit increments retryCount until max, then deletes entity
    func test_9_retryLimit_increments_retryCount_until_max_then_deletes_entity() async throws {
        let id = try makeUpdate(maxRetryCount: 2)

        let deleted1 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted1)

        let first = try XCTUnwrap(fetchUpdate(by: id))
        XCTAssertEqual(first.retryCount, 1)

        let deleted2 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted2)

        let second = try XCTUnwrap(fetchUpdate(by: id))
        XCTAssertEqual(second.retryCount, 2)

        let deleted3 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertTrue(deleted3)

        let all = try fetchAllUpdates()
        XCTAssertTrue(all.isEmpty)
    }
}
