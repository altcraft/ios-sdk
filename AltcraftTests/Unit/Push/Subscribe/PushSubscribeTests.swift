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
 *  - test_1: signAll success chain deletes all subscriptions.
 *  - test_2: signAll retry without limit stops and increments retryCount.
 *  - test_3: signAll retry with limit treated as completed then continues.
 *  - test_4: processSubscriptions filters by current userTag only.
 *  - test_5: processSubscriptions returns true when no subscriptions.
 *  - test_6: responseProcessing maps status codes to event types.
 *  - test_7: signAll retry with invalid objectID treated as completed.
 *  - test_8: signAll retry with wrong type objectID deletes and completes.
 */
final class PushSubscribeTests: IsolatedTestCase {

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

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = TestablePushSubscribe()
        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
    }

    override func tearDownWithError() throws {
        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sut = nil
        try super.tearDownWithError()
    }

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

    private func countSubs() -> Int {
        var n = 0
        viewContext.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribe)
            n = (try? viewContext.count(for: fr)) ?? 0
        }
        return n
    }

    private func loadSub(_ id: NSManagedObjectID) -> SubscribeEntity? {
        var obj: SubscribeEntity?
        viewContext.performAndWait {
            obj = try? viewContext.existingObject(with: id) as? SubscribeEntity
        }
        return obj
    }

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

    /// test_1: signAll success chain deletes all subscriptions
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

    /// test_2: signAll retry without limit stops and increments retryCount
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

    /// test_3: signAll retry with limit treated as completed then continues
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

    /// test_4: processSubscriptions filters by current userTag only
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

    /// test_5: processSubscriptions returns true when no subscriptions
    func test_5_processSubscriptions_returns_true_when_no_subscriptions() {
        seedConfig(rToken: "user-1")

        let exp = expectation(description: "no subs -> true")
        sut.processSubscriptions(context: viewContext) { completed in
            XCTAssertTrue(completed)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1.0)
    }

    /// test_6: responseProcessing maps status codes to event types
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

    /// test_7: signAll retry with invalid objectID treated as completed
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

    /// test_8: signAll retry with wrong type objectID deletes and completes
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
