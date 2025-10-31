//
//  PushEventTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushEventTests
 *
 * Positive scenarios:
 *  - test_1: createPushEvent → persists entity and invokes send.
 *  - test_2: sendAllPushEvents → calls send for each pending event.
 *  - test_3: sendPushEvent success → deletes entity via overridden request.
 *  - test_4: sendPushEvent retry → increments retryCount via overridden request.
 */
final class PushEventTests: IsolatedTestCase {

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

    private final class SpyPushEvent: PushEvent {
        struct Call { let objectID: NSManagedObjectID; let shouldRetry: Bool }
        private(set) var calls: [Call] = []
        private let onSendCompletion: (() -> Void)?

        init(onSendCompletion: (() -> Void)? = nil) {
            self.onSendCompletion = onSendCompletion
            super.init()
        }

        override func sendPushEvent(
            context: NSManagedObjectContext? = nil,
            objectID: NSManagedObjectID,
            shouldRetry: Bool = true,
            completion: (() -> Void)? = nil
        ) {
            calls.append(.init(objectID: objectID, shouldRetry: shouldRetry))
            onSendCompletion?()
            completion?()
        }
    }

    private final class PushEventSuccessStub: PushEvent {
        override func sendPushEventRequest(
            context: NSManagedObjectContext,
            objectID: NSManagedObjectID,
            completion: @escaping (Event) -> Void
        ) {
            completion(event(#function, event: (200, "ok")))
        }
    }

    private final class PushEventRetryStub: PushEvent {
        override func sendPushEventRequest(
            context: NSManagedObjectContext,
            objectID: NSManagedObjectID,
            completion: @escaping (Event) -> Void
        ) {
            completion(retryEvent(#function, error: (503, "temporary")))
        }
    }

    /// test_1: createPushEvent persists entity and invokes send
    func test_1_createPushEvent_persistsEntity_andInvokesSend() {
        let expSend = expectation(description: "send invoked")
        let spy = SpyPushEvent(onSendCompletion: { expSend.fulfill() })

        let uid = "u-123"
        let userInfo: [String: Any] = [Constants.UserInfoKeys.uid: uid]

        spy.createPushEvent(userInfo: userInfo, type: "delivered")
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 1)

        let rows = fetchAllPushEventsAsc()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].uid, uid)
        XCTAssertEqual(rows[0].type, "delivered")

        XCTAssertEqual(spy.calls.count, 1)
        XCTAssertEqual(spy.calls.first?.objectID, rows[0].objectID)
    }

    /// test_2: sendAllPushEvents calls send for each pending event
    func test_2_sendAllPushEvents_callsSend_forEachPendingEvent() {
        let group = DispatchGroup()
        for i in 0..<5 {
            group.enter()
            addPushEventEntity(uid: "uid-\(i)", type: "opened") { _ in group.leave() }
        }
        let ok = group.wait(timeout: .now() + timeoutShort)
        XCTAssertEqual(ok, .success, "Seeding timed out")

        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 5)

        let expAll = expectation(description: "all sends done")
        let spy = SpyPushEvent()
        spy.sendAllPushEvents { expAll.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(spy.calls.count, 5)

        let existingIDs = Set(fetchAllPushEventsAsc().map { $0.objectID })
        let calledIDs   = Set(spy.calls.map { $0.objectID })
        XCTAssertEqual(existingIDs, calledIDs)
    }

    /// test_3: sendPushEvent success deletes entity via overridden request
    func test_3_sendPushEvent_success_deletesEntity_viaOverriddenRequest() {
        let expCreate = expectation(description: "seed")
        var objectID: NSManagedObjectID?
        addPushEventEntity(uid: "ok-1", type: "delivered") { oid in objectID = oid; expCreate.fulfill() }
        waitForExpectations(timeout: timeoutShort)
        guard let id = objectID else { return XCTFail("Seed failed") }

        let expDone = expectation(description: "send completed")
        let sut = PushEventSuccessStub()
        sut.sendPushEvent(objectID: id, shouldRetry: false) { expDone.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(self.sdkCount(Constants.EntityNames.pushEvent), 0)
    }

    /// test_4: sendPushEvent retry increments retryCount via overridden request
    func test_4_sendPushEvent_retry_incrementsRetryCount_viaOverriddenRequest() {
        let expCreate = expectation(description: "seed")
        var objectID: NSManagedObjectID?
        addPushEventEntity(uid: "retry-1", type: "opened") { oid in objectID = oid; expCreate.fulfill() }
        waitForExpectations(timeout: timeoutShort)
        guard let id = objectID else { return XCTFail("Seed failed") }

        let expDone = expectation(description: "send completed")
        let sut = PushEventRetryStub()
        sut.sendPushEvent(objectID: id, shouldRetry: false) { expDone.fulfill() }
        waitForExpectations(timeout: timeoutShort)

        let rows = fetchAllPushEventsAsc()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].retryCount, 1)
    }
}
