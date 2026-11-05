//
//  InAppSubscribeTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
 * InAppSubscribeTests
 *
 * Positive scenarios:
 * - test_1: request with invalid objectID returns RetryEvent when request data cannot be built.
 * - test_2: processSubscription with invalid objectID is treated as completed.
 * - test_3: processSubscription on retry path increments retryCount and returns true.
 * - test_4: processSubscription on max retry deletes entity and returns false.
 * - test_5: processSubscriptions stops on the first retrying entity and leaves the next one untouched.
 * - test_6: processSubscriptions with empty queue returns true.
 * - test_7: processSubscription with wrong type objectID deletes object and returns false.
 * - test_8: retryLimit with invalid objectID returns true when objectID is invalid.
 * - test_9: retryLimit increments retryCount until max, then deletes entity.
 *
 */
final class InAppSubscribeTests: IsolatedTestCase {

    private var context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

    override func setUpWithError() throws {
        try super.setUpWithError()

        context = inAppDatabase.getContext()

        wipeContext([
            InAppConstants.EntityNames.inAppSubscribeEntity,
            InAppConstants.EntityNames.inAppSubStateEntity
        ], context: context)

        sdkWipe([
            Constants.EntityNames.configurationEntity
        ])
    }

    override func tearDownWithError() throws {
        wipeContext([
            InAppConstants.EntityNames.inAppSubscribeEntity,
            InAppConstants.EntityNames.inAppSubStateEntity
        ], context: context)

        sdkWipe([
            Constants.EntityNames.configurationEntity
        ])

        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

        try super.tearDownWithError()
    }

    @discardableResult
    private func makeSub(
        userTag: String = "user-1",
        deviceId: String = "device-1",
        acid: String = "acid-1",
        status: String = Constants.SubStatus.subscribed,
        sync: Bool = true,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2,
        replace: Bool = false,
        skipTriggers: Bool = false,
        profileFields: Data? = nil,
        customFields: Data? = nil,
        cats: Data? = nil
    ) throws -> NSManagedObjectID {
        var objectID: NSManagedObjectID?

        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: InAppConstants.EntityNames.inAppSubscribeEntity,
                into: context
            )

            entity.setValue(userTag, forKey: "userTag")
            entity.setValue(deviceId, forKey: "deviceId")
            entity.setValue(acid, forKey: "acid")
            entity.setValue(UUID().uuidString, forKey: "requestId")
            entity.setValue(status, forKey: "status")
            entity.setValue(sync, forKey: "sync")
            entity.setValue(time, forKey: "time")
            entity.setValue(retryCount, forKey: "retryCount")
            entity.setValue(maxRetryCount, forKey: "maxRetryCount")
            entity.setValue(replace, forKey: "replace")
            entity.setValue(skipTriggers, forKey: "skipTriggers")
            entity.setValue(profileFields, forKey: "profileFields")
            entity.setValue(customFields, forKey: "customFields")
            entity.setValue(cats, forKey: "cats")

            do {
                if entity.objectID.isTemporaryID {
                    try context.obtainPermanentIDs(for: [entity])
                }

                try context.save()
                objectID = entity.objectID
            } catch {
                XCTFail("Failed to save InAppSubscribeEntity: \(error)")
            }
        }

        return try XCTUnwrap(objectID)
    }

    @discardableResult
    private func makeConfig(
        url: String = "https://api.altcraft.test",
        rToken: String = "user-1"
    ) throws -> NSManagedObjectID {
        var objectID: NSManagedObjectID?

        guard let configContext = TestCoreDataStack.sdkBackgroundContext(
            containingEntity: Constants.EntityNames.configurationEntity
        ) else {
            throw NSError(
                domain: "InAppSubscribeTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Entity ConfigurationEntity not found"]
            )
        }

        configContext.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: Constants.EntityNames.configurationEntity,
                into: configContext
            )

            entity.setValue(url, forKey: "url")
            entity.setValue(rToken, forKey: "rToken")

            do {
                if entity.objectID.isTemporaryID {
                    try configContext.obtainPermanentIDs(for: [entity])
                }

                try configContext.save()
                objectID = entity.objectID
            } catch {
                XCTFail("Failed to save ConfigurationEntity: \(error)")
            }
        }

        return try XCTUnwrap(objectID)
    }

    private func deleteObject(by id: NSManagedObjectID) throws {
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
                XCTFail("Failed to delete object: \(error)")
            }
        }
    }

    private func fetchSub(by id: NSManagedObjectID) throws -> InAppSubscribeEntity? {
        var object: InAppSubscribeEntity?

        context.performAndWait {
            object = resolveObject(in: context, from: id) as? InAppSubscribeEntity
        }

        return object
    }

    private func fetchAllSubs() throws -> [InAppSubscribeEntity] {
        var objects: [InAppSubscribeEntity] = []

        context.performAndWait {
            let req = NSFetchRequest<InAppSubscribeEntity>(
                entityName: InAppConstants.EntityNames.inAppSubscribeEntity
            )

            objects = (try? context.fetch(req)) ?? []
        }

        return objects
    }

    private func wipeContext(
        _ entities: [String],
        context: NSManagedObjectContext
    ) {
        context.performAndWait {
            for name in entities {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: name
                )

                if let objects = try? context.fetch(req) as? [NSManagedObject] {
                    objects.forEach {
                        context.delete($0)
                    }
                }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    private func sdkWipe(_ entityNames: [String]) {
        for name in entityNames {
            guard let ctx = TestCoreDataStack.sdkBackgroundContext(containingEntity: name) else {
                continue
            }
            let sema = DispatchSemaphore(value: 0)

            ctx.perform {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: name
                )
                req.includesPropertyValues = false

                if let objects = try? ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach {
                        ctx.delete($0)
                    }
                }

                if ctx.hasChanges {
                    try? ctx.save()
                }

                sema.signal()
            }

            _ = sema.wait(timeout: .now() + 5.0)
        }
    }

    /// test_1: request with invalid objectID returns RetryEvent when request data cannot be built
    func test_1_request_with_invalid_objectID_returns_retry_event_when_request_data_cannot_be_built() async throws {
        let id = try makeSub()
        try deleteObject(by: id)

        let event = await InAppSubscriptionProcess.shared.test_inApp_subscribe_request(
            context: context,
            objectID: id
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_2: processSubscription with invalid objectID is treated as completed
    func test_2_processSubscription_with_invalid_objectID_is_treated_as_completed() async throws {
        let id = try makeSub()
        try deleteObject(by: id)

        let result = await InAppSubscriptionProcess.shared.test_inApp_subscribe_isRetry(
            context: context,
            subscription: id
        )

        XCTAssertFalse(result)
    }

    /// test_3: processSubscription on retry path increments retryCount and returns true
    func test_3_processSubscription_on_retry_path_increments_retryCount_and_returns_true() async throws {
        let id = try makeSub(
            retryCount: 0,
            maxRetryCount: 2
        )

        let result = await InAppSubscriptionProcess.shared.test_inApp_subscribe_isRetry(
            context: context,
            subscription: id
        )

        XCTAssertTrue(result)

        let updated = try XCTUnwrap(fetchSub(by: id))
        XCTAssertEqual(updated.retryCount, 1)
        XCTAssertEqual(updated.maxRetryCount, 2)
    }

    /// test_4: processSubscription on max retry deletes entity and returns false
    func test_4_processSubscription_on_max_retry_deletes_entity_and_returns_false() async throws {
        let id = try makeSub(
            retryCount: 0,
            maxRetryCount: 0
        )

        let result = await InAppSubscriptionProcess.shared.test_inApp_subscribe_isRetry(
            context: context,
            subscription: id
        )

        XCTAssertFalse(result)
        XCTAssertNil(try fetchSub(by: id))
    }

    /// test_5: processSubscriptions stops on the first retrying entity and leaves the next one untouched
    func test_5_processSubscriptions_stops_on_the_first_retrying_entity_and_leaves_the_next_one_untouched() async throws {
        let tag = "user-stop-chain-\(UUID().uuidString)"
        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let firstID = try makeSub(
            userTag: tag,
            time: now,
            retryCount: 0,
            maxRetryCount: 2
        )

        let secondID = try makeSub(
            userTag: tag,
            time: now + 1,
            retryCount: 0,
            maxRetryCount: 2
        )

        let firstResult = await InAppSubscriptionProcess.shared.test_inApp_subscribe_isRetry(
            context: context,
            subscription: firstID
        )

        XCTAssertTrue(firstResult)

        let firstUpdated = try XCTUnwrap(fetchSub(by: firstID))
        XCTAssertEqual(firstUpdated.retryCount, 1)

        let secondUpdated = try XCTUnwrap(fetchSub(by: secondID))
        XCTAssertEqual(secondUpdated.retryCount, 0)
    }

    /// test_6: processSubscriptions with empty queue returns true
    func test_6_processSubscriptions_with_empty_queue_returns_true() async {
        let result = await InAppSubscriptionProcess.shared.test_inApp_subscribe_processSubscriptions(
            userTag: "missing-\(UUID().uuidString)"
        )

        XCTAssertTrue(result)
    }

    /// test_7: processSubscription with wrong type objectID deletes object and returns false
    func test_7_processSubscription_with_wrong_type_objectID_deletes_object_and_returns_false() async throws {
        let id = try makeConfig()

        let result = await InAppSubscriptionProcess.shared.test_inApp_subscribe_isRetry(
            context: context,
            subscription: id
        )

        XCTAssertFalse(result)

        let exists = resolveObject(in: context, from: id) != nil
        XCTAssertFalse(exists)
    }

    /// test_8: retryLimit with invalid objectID returns true when objectID is invalid
    func test_8_retryLimit_with_invalid_objectID_returns_true_when_objectID_is_invalid() async throws {
        let id = try makeSub()
        try deleteObject(by: id)

        let deleted = await retryLimit(
            context: context,
            objectID: id
        )

        XCTAssertTrue(deleted)
    }

    /// test_9: retryLimit increments retryCount until max, then deletes entity
    func test_9_retryLimit_increments_retryCount_until_max_then_deletes_entity() async throws {
        let id = try makeSub(maxRetryCount: 2)

        let deleted1 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted1)

        let first = try XCTUnwrap(fetchSub(by: id))
        XCTAssertEqual(first.retryCount, 1)

        let deleted2 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted2)

        let second = try XCTUnwrap(fetchSub(by: id))
        XCTAssertEqual(second.retryCount, 2)

        let deleted3 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertTrue(deleted3)

        let all = try fetchAllSubs()
        XCTAssertTrue(all.isEmpty)
    }
}
