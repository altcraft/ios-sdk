//
//  PushSubscribeTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * PushSubscribeTests
 *
 * Positive scenarios:
 *  - test_1_signAll_success_chain_deletes_all:
 *      signAll processes a sequence of successes and deletes all rows.
 *  - test_2_signAll_retry_without_limit_stops_and_increments_retryCount:
 *      on RetryEvent below limit the chain stops and retryCount is incremented.
 *  - test_3_signAll_retry_with_limit_treated_as_completed_then_continues:
 *      on RetryEvent at limit the row is treated as completed (deleted) and processing continues.
 *  - test_4_processSubscriptions_filters_by_current_userTag_only:
 *      processSubscriptions handles only rows for the current userTag.
 *  - test_5_processSubscriptions_returns_true_when_no_subscriptions:
 *      returns true when there is nothing to process for the current userTag.
 *  - test_6_responseProcessing_maps_status_codes_to_event_types:
 *      RequestManager.responseProcessing maps HTTP status codes to Event/ErrorEvent/RetryEvent.
 *  - test_7_signAll_retry_with_invalid_objectID_treated_as_completed:
 *      invalid objectID with RetryEvent is treated as completed (no retry).
 *  - test_8_signAll_retry_with_wrong_type_objectID_deletes_and_completes:
 *      wrong-type objectID on RetryEvent is deleted and chain completes.
 *
 * Notes:
 *  - Production code is unchanged. Network is simulated by overriding sendSubscribeRequest.
 *  - setUp/tearDown also wipe the SDK Core Data container to avoid cross-test leakage.
 */
final class PushSubscribeTests: IsolatedTestCase {

    /// Test double that allows per-object success/retry behavior without touching production code.
    private final class TestablePushSubscribe: PushSubscribe {
        enum Behavior { case success, retry }
        var perObjectBehavior: [NSManagedObjectID: Behavior] = [:]
        var defaultBehavior: Behavior = .success

        override func sendSubscribeRequest(
            context: NSManagedObjectContext,
            objectID: NSManagedObjectID,
            completion: @escaping (Event) -> Void
        ) {
            let behavior = perObjectBehavior[objectID] ?? defaultBehavior
            switch behavior {
            case .success: completion(Event(function: "sendSubscribeRequest"))
            case .retry:   completion(RetryEvent(function: "sendSubscribeRequest"))
            }
        }
    }

    private var sut: TestablePushSubscribe!

    /// Prepares an isolated SUT and wipes both in-memory and SDK Core Data stores.
    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = TestablePushSubscribe()
        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
    }

    /// Cleans up SUT and fully wipes stores to preserve test isolation.
    override func tearDownWithError() throws {
        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sut = nil
        try super.tearDownWithError()
    }

    /// Removes all objects for the given entity names from the in-memory test container.
    private func wipeInMemory(_ entities: [String]) {
        viewContext.performAndWait {
            for name in entities {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                if let list = try? viewContext.fetch(fr) as? [NSManagedObject] {
                    list.forEach { viewContext.delete($0) }
                }
            }
            try? viewContext.save()
        }
    }

    /// Removes all objects for the given entity names from the SDK Core Data container.
    private func sdkWipe(_ entityNames: [String]) {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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

    /// Creates and persists a SubscribeEntity with the provided parameters.
    @discardableResult
    private func makeSub(
        userTag: String = "user-1",
        status: String = "subscribed",
        sync: Int16 = 1,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 3
    ) throws -> SubscribeEntity {
        let e = SubscribeEntity(context: viewContext)
        e.userTag = userTag
        e.status = status
        e.sync = sync
        e.time = time
        e.retryCount = retryCount
        e.maxRetryCount = maxRetryCount
        try viewContext.obtainPermanentIDs(for: [e])
        try viewContext.save()
        return e
    }

    /// Counts SubscribeEntity rows in the in-memory context.
    private func countSubs() -> Int {
        var n = 0
        viewContext.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribe)
            n = (try? viewContext.count(for: fr)) ?? 0
        }
        return n
    }

    /// Loads a SubscribeEntity by objectID from the in-memory context.
    private func loadSub(_ id: NSManagedObjectID) -> SubscribeEntity? {
        var obj: SubscribeEntity?
        viewContext.performAndWait {
            obj = try? viewContext.existingObject(with: id) as? SubscribeEntity
        }
        return obj
    }

    /// Seeds a minimal ConfigurationEntity in the SDK container to drive getUserTag().
    private func seedConfig(rToken: String) {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        ctx.performAndWait {
            let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            let entity = ((try? ctx.fetch(req))?.first) ?? ConfigurationEntity(context: ctx)
            entity.url = "https://api"
            entity.rToken = rToken
            try? ctx.save()
        }
    }

    /// signAll with all-success responses should delete every row and return false (no retry needed).
    func test_1_signAll_success_chain_deletes_all() throws {
        let s1 = try makeSub(time: 1_700_000_000_001)
        let s2 = try makeSub(time: 1_700_000_000_002)
        let s3 = try makeSub(time: 1_700_000_000_003)

        sut.defaultBehavior = .success

        let exp = expectation(description: "done")
        sut.signAll(context: viewContext, subscriptions: [s1.objectID, s2.objectID, s3.objectID]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(countSubs(), 0)
    }

    /// signAll with a RetryEvent below the limit should stop the chain and increment retryCount.
    func test_2_signAll_retry_without_limit_stops_and_increments_retryCount() throws {
        let s = try makeSub(retryCount: 0, maxRetryCount: 2)
        sut.perObjectBehavior[s.objectID] = .retry

        let exp = expectation(description: "stopped on retry")
        sut.signAll(context: viewContext, subscriptions: [s.objectID]) { retryNeeded in
            XCTAssertTrue(retryNeeded)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        let after = loadSub(s.objectID)
        XCTAssertNotNil(after)
        XCTAssertEqual(after?.retryCount, 1)
        XCTAssertEqual(countSubs(), 1)
    }

    /// signAll with a RetryEvent at the limit should delete the row and continue with the next.
    func test_3_signAll_retry_with_limit_treated_as_completed_then_continues() throws {
        let first  = try makeSub(retryCount: 2, maxRetryCount: 2)
        let second = try makeSub(retryCount: 0, maxRetryCount: 3)

        sut.perObjectBehavior[first.objectID]  = .retry
        sut.perObjectBehavior[second.objectID] = .success

        let exp = expectation(description: "completed chain")
        sut.signAll(context: viewContext, subscriptions: [first.objectID, second.objectID]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(countSubs(), 0)
    }

    /// processSubscriptions should process rows only for the current userTag sourced from configuration.
    func test_4_processSubscriptions_filters_by_current_userTag_only() throws {
        seedConfig(rToken: "user-1")

        let a1 = try makeSub(userTag: "user-1", time: 1)
        let a2 = try makeSub(userTag: "user-1", time: 2)
        _ = try makeSub(userTag: "user-2", time: 3)

        sut.defaultBehavior = .success

        let exp = expectation(description: "process current tag only")
        sut.processSubscriptions(context: viewContext) { completed in
            XCTAssertTrue(completed)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        var remainsForUser2 = 0
        viewContext.performAndWait {
            let fr = NSFetchRequest<SubscribeEntity>(entityName: Constants.EntityNames.subscribe)
            fr.predicate = NSPredicate(format: "userTag == %@", "user-2")
            remainsForUser2 = (try? viewContext.count(for: fr as! NSFetchRequest<NSFetchRequestResult>)) ?? 0
        }

        XCTAssertNil(loadSub(a1.objectID))
        XCTAssertNil(loadSub(a2.objectID))
        XCTAssertEqual(remainsForUser2, 1)
    }

    /// processSubscriptions should return true when there is nothing to process.
    func test_5_processSubscriptions_returns_true_when_no_subscriptions() {
        seedConfig(rToken: "user-1")

        let exp = expectation(description: "no subs -> true")
        sut.processSubscriptions(context: viewContext) { completed in
            XCTAssertTrue(completed)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    /// responseProcessing should map status codes to correct Event types.
    func test_6_responseProcessing_maps_status_codes_to_event_types() {
        let mgr = RequestManager()
        let url = URL(string: "https://example.com")!
        func http(_ code: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: [:])!
        }

        let body = """
        {"result":"ok","detail":"unit"}
        """.data(using: .utf8)

        let ok = mgr.responseProcessing(response: http(200), data: body, requestName: Constants.RequestName.subscribe)
        let srvErr = mgr.responseProcessing(response: http(503), data: body, requestName: Constants.RequestName.subscribe)
        let cliErr = mgr.responseProcessing(response: http(404), data: body, requestName: Constants.RequestName.subscribe)

        XCTAssertTrue(type(of: ok) == Event.self)
        XCTAssertFalse(type(of: ok) == ErrorEvent.self)
        XCTAssertTrue(type(of: srvErr) == RetryEvent.self)
        XCTAssertTrue(type(of: cliErr) == ErrorEvent.self)
        XCTAssertFalse(type(of: cliErr) == RetryEvent.self)
    }

    /// A RetryEvent with an invalid objectID should be treated as completed (no retry).
    func test_7_signAll_retry_with_invalid_objectID_treated_as_completed() throws {
        let s = try makeSub()
        let id = s.objectID
        viewContext.delete(s)
        try viewContext.save()

        sut.perObjectBehavior[id] = .retry

        let exp = expectation(description: "invalid id -> completed")
        sut.signAll(context: viewContext, subscriptions: [id]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        XCTAssertEqual(countSubs(), 0)
    }

    /// A RetryEvent on a wrong-type objectID should delete that object and complete.
    func test_8_signAll_retry_with_wrong_type_objectID_deletes_and_completes() {
        let cfg = ConfigurationEntity(context: viewContext)
        cfg.url = "https://api"
        cfg.rToken = "T"
        try? viewContext.save()
        let id = cfg.objectID

        sut.perObjectBehavior[id] = .retry

        let exp = expectation(description: "wrong type -> deleted & completed")
        sut.signAll(context: viewContext, subscriptions: [id]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        var exists = true
        viewContext.performAndWait {
            exists = (try? self.viewContext.existingObject(with: id)) != nil
        }
        XCTAssertFalse(exists)
    }
}

