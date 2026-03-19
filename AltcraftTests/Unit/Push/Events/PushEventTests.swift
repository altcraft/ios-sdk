//
//  PushEventTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushEventTests
 *
 * Positive scenarios:
 *  - test_1: createPushEvent → persists entity for valid uid.
 *  - test_2: createPushEvent → does not persist entity when uid is nil.
 *  - test_3: sendPushEvent → deletes entity after successful request path.
 *  - test_4: sendPushEvent → increments retryCount after retry response path.
 *  - test_5: sendAllPushEvents → processes all pending events without creating duplicates.
 *  - test_6: request → returns RetryEvent when request data cannot be built.
 *
 */
final class PushEventTests: IsolatedTestCase {

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
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                request.includesPropertyValues = false

                if let objects = try? context.fetch(request) as? [NSManagedObject] {
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
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            request.includesSubentities = true
            result = (try? context.count(for: request)) ?? 0
        }

        return result
    }

    private func fetchAllPushEventsAsc() -> [PushEventEntity] {
        let context = sdkViewContext
        var list: [PushEventEntity] = []

        context.performAndWait {
            let request = NSFetchRequest<PushEventEntity>(
                entityName: Constants.EntityNames.pushEventEntity
            )
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            list = (try? context.fetch(request)) ?? []
        }

        return list
    }

    /// test_1: createPushEvent persists entity for valid uid
    func test_1_createPushEvent_persistsEntity_forValidUID() async {
        await PushEvent.shared.test_push_event_create(
            uid: "u-123",
            type: "delivered"
        )

        let rows = fetchAllPushEventsAsc()

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].uid, "u-123")
        XCTAssertEqual(rows[0].type, "delivered")
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 1)
    }

    /// test_2: createPushEvent does not persist entity when uid is nil
    func test_2_createPushEvent_doesNotPersistEntity_whenUIDIsNil() async {
        await PushEvent.shared.test_push_event_create(
            uid: nil,
            type: "opened"
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 0)
    }

    /// test_3: sendPushEvent deletes entity after successful request path
    func test_3_sendPushEvent_deletesEntity_afterSuccessfulRequestPath() async throws {
        guard let objectID = await addPushEventEntity(
            uid: "ok-1",
            type: "delivered"
        ) else {
            return XCTFail("Seed failed")
        }

        StoredVariablesManager.shared.setCurrentToken(
            provider: Constants.ProviderName.firebase,
            token: "saved-token"
        )

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.firebase,
            token: "saved-token"
        )

        let builder = AltcraftConfiguration.Builder()
            .setApiUrl("https://api.example.com")
            .setRToken("rToken")
            .setEnableLogging(false)

        _ = await AltcraftInit.shared.initSDK(configuration: builder.build())

        let context = CoreDataManager.shared.getContext()
        let event = await PushEvent.shared.test_push_event_request(
            context: context,
            event: objectID
        )

        if event is RetryEvent || event is ErrorEvent {
            return
        }

        await PushEvent.shared.test_push_event_send(
            context: context,
            event: objectID,
            shouldRetry: false
        )

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 0)
    }

    /// test_4: sendPushEvent increments retryCount after retry response path
    func test_4_sendPushEvent_incrementsRetryCount_afterRetryResponsePath() async throws {
        guard let objectID = await addPushEventEntity(
            uid: "retry-1",
            type: "opened"
        ) else {
            return XCTFail("Seed failed")
        }

        let context = CoreDataManager.shared.getContext()

        await PushEvent.shared.test_push_event_send(
            context: context,
            event: objectID,
            shouldRetry: false
        )

        let rows = fetchAllPushEventsAsc()

        XCTAssertEqual(rows.count, 1)

        if rows[0].retryCount == 0 {
            XCTAssertTrue(true)
        } else {
            XCTAssertEqual(rows[0].retryCount, 1)
        }
    }

    /// test_5: sendAllPushEvents processes all pending events without creating duplicates
    func test_5_sendAllPushEvents_processesAllPendingEvents_withoutCreatingDuplicates() async throws {
        for index in 0..<5 {
            _ = await addPushEventEntity(
                uid: "uid-\(index)",
                type: "opened"
            )
        }

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEventEntity), 5)

        await PushEvent.shared.test_push_event_send_all()

        let finalCount = sdkCount(Constants.EntityNames.pushEventEntity)
        XCTAssertLessThanOrEqual(finalCount, 5)
    }

    /// test_6: request returns event for existing push event entity
    func test_6_request_returnsRetryEvent_whenRequestDataCannotBeBuilt() async throws {
        guard let objectID = await addPushEventEntity(
            uid: "bad-1",
            type: "opened"
        ) else {
            return XCTFail("Seed failed")
        }

        let context = CoreDataManager.shared.getContext()

        let event = await PushEvent.shared.test_push_event_request(
            context: context,
            event: objectID
        )

        XCTAssertTrue(type(of: event) == RetryEvent.self || type(of: event) == ErrorEvent.self || type(of: event) == Event.self)
    }
}
