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
 *  - test_9: signAll success saves current token and deletes subscription.
 *  - test_10: signAll error deletes subscription and continues chain.
 *  - test_11: signAll success but current token is nil stops with retry and does not delete.
 */
final class PushSubscribeTests: IsolatedTestCase {

    private final class TestAPNSProvider: APNSInterface {
        func getToken(completion: @escaping (String?) -> Void) {
            completion("TEST-APNS-TOKEN")
        }
    }

    private final class TestablePushSubscribe: PushSubscribe {
        enum Behavior { case success, retry, error }
        var perObjectBehavior: [NSManagedObjectID: Behavior] = [:]
        var defaultBehavior: Behavior = .success

        override func sendSubscribeRequest(
            context: NSManagedObjectContext,
            objectID: NSManagedObjectID,
            completion: @escaping (Event) -> Void
        ) {
            let behavior = perObjectBehavior[objectID] ?? defaultBehavior
            switch behavior {
            case .success:
                completion(Event(function: "sendSubscribeRequest"))
            case .retry:
                completion(RetryEvent(function: "sendSubscribeRequest"))
            case .error:
                completion(ErrorEvent(function: "sendSubscribeRequest"))
            }
        }
    }

    private var sut: TestablePushSubscribe!
    private var apnsStub: TestAPNSProvider!

    private func performSync(_ context: NSManagedObjectContext, _ block: @escaping () -> Void) {
        if context.concurrencyType == .mainQueueConcurrencyType, Thread.isMainThread {
            block()
            return
        }
        let sema = DispatchSemaphore(value: 0)
        context.perform {
            block()
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 5.0)
    }

    private func performSync<T>(_ context: NSManagedObjectContext, _ block: @escaping () -> T) -> T {
        if context.concurrencyType == .mainQueueConcurrencyType, Thread.isMainThread {
            return block()
        }
        let sema = DispatchSemaphore(value: 0)
        var out: T!
        context.perform {
            out = block()
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 5.0)
        return out
    }

    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2.0,
        poll: TimeInterval = 0.01,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping () -> Bool
    ) {
        let exp = expectation(description: description)

        func tick(deadline: DispatchTime) {
            if predicate() {
                exp.fulfill()
                return
            }
            if DispatchTime.now() >= deadline { return }
            DispatchQueue.global().asyncAfter(deadline: .now() + poll) {
                tick(deadline: deadline)
            }
        }

        tick(deadline: .now() + timeout)
        wait(for: [exp], timeout: timeout + 0.2)
        XCTAssertTrue(predicate(), file: file, line: line)
    }

    // MARK: - Setup / teardown

    override func setUpWithError() throws {
        try super.setUpWithError()

        apnsStub = TestAPNSProvider()
        TokenManager.shared.apnsProvider = apnsStub
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil

        sut = TestablePushSubscribe()

        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])
    }

    override func tearDownWithError() throws {
        wipeInMemory([Constants.EntityNames.subscribe, Constants.EntityNames.config])
        sdkWipe([Constants.EntityNames.subscribe, Constants.EntityNames.config])

        sut = nil

        TokenManager.shared.apnsProvider = nil
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil
        apnsStub = nil

        try super.tearDownWithError()
    }

    // MARK: - DB helpers

    private func wipeInMemory(_ entities: [String]) {
        performSync(viewContext) {
            for name in entities {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                if let list = try? self.viewContext.fetch(fr) as? [NSManagedObject] {
                    list.forEach { self.viewContext.delete($0) }
                }
            }
            if self.viewContext.hasChanges { try? self.viewContext.save() }
        }
    }

    private func sdkWipe(_ entityNames: [String]) {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        performSync(bg) {
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
        maxRetryCount: Int16 = 3,
        replace: Bool = false,
        skipTriggers: Bool = false
    ) throws -> SubscribeEntity {

        var created: SubscribeEntity?
        var caught: Error?

        performSync(viewContext) {
            guard let ent = NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.subscribe,
                in: self.viewContext
            ) else {
                caught = NSError(domain: "tests", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "Missing entity \(Constants.EntityNames.subscribe)"
                ])
                return
            }

            let obj = SubscribeEntity(entity: ent, insertInto: self.viewContext)
            obj.userTag = userTag
            obj.status = status
            obj.sync = sync
            obj.time = time
            obj.retryCount = retryCount
            obj.maxRetryCount = maxRetryCount
            obj.replace = replace
            obj.skipTriggers = skipTriggers

            do {
                try self.viewContext.obtainPermanentIDs(for: [obj])
                try self.viewContext.save()
                created = obj
            } catch {
                caught = error
            }
        }

        if let caught { throw caught }
        guard let created else {
            throw NSError(domain: "tests", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "SubscribeEntity was not created"
            ])
        }
        return created
    }

    private func makeConfig(url: String = "https://api", rToken: String) throws -> ConfigurationEntity {
        var created: ConfigurationEntity?
        var caught: Error?

        performSync(viewContext) {
            guard let ent = NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.config,
                in: self.viewContext
            ) else {
                caught = NSError(domain: "tests", code: 1101, userInfo: [
                    NSLocalizedDescriptionKey: "Missing entity \(Constants.EntityNames.config)"
                ])
                return
            }

            let obj = ConfigurationEntity(entity: ent, insertInto: self.viewContext)
            obj.url = url
            obj.rToken = rToken

            do {
                try self.viewContext.obtainPermanentIDs(for: [obj])
                try self.viewContext.save()
                created = obj
            } catch {
                caught = error
            }
        }

        if let caught { throw caught }
        guard let created else {
            throw NSError(domain: "tests", code: 1102, userInfo: [
                NSLocalizedDescriptionKey: "ConfigurationEntity was not created"
            ])
        }
        return created
    }

    private func countSubs() -> Int {
        performSync(viewContext) {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribe)
            return (try? self.viewContext.count(for: fr)) ?? 0
        }
    }

    private func loadSub(_ id: NSManagedObjectID) -> SubscribeEntity? {
        performSync(viewContext) {
            (try? self.viewContext.existingObject(with: id)) as? SubscribeEntity
        }
    }

    private func seedConfigToSDKStore(rToken: String) {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        performSync(ctx) {
            let req: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            let entity = ((try? ctx.fetch(req))?.first) ?? ConfigurationEntity(context: ctx)
            entity.url = "https://api"
            entity.rToken = rToken
            try? ctx.save()
        }
    }

    // MARK: - Tests

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
        wait(for: [exp], timeout: 2.0)

        waitUntil("subscriptions deleted", timeout: 3.0) { self.countSubs() == 0 }
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
        wait(for: [exp], timeout: 2.0)

        waitUntil("retryCount incremented", timeout: 3.0) {
            (self.loadSub(s.objectID)?.retryCount ?? 0) == 1
        }

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
        wait(for: [exp], timeout: 2.0)

        waitUntil("subscriptions deleted", timeout: 3.0) { self.countSubs() == 0 }
        XCTAssertEqual(countSubs(), 0)
    }

    /// test_4: processSubscriptions filters by current userTag only
    func test_4_processSubscriptions_filters_by_current_userTag_only() throws {
        seedConfigToSDKStore(rToken: "user-1")

        let a1 = try makeSub(userTag: "user-1", time: 1)
        let a2 = try makeSub(userTag: "user-1", time: 2)
        _ = try makeSub(userTag: "user-2", time: 3)

        sut.defaultBehavior = .success

        let exp = expectation(description: "process current tag only")
        sut.processSubscriptions(context: viewContext) { completed in
            XCTAssertTrue(completed)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("user-1 subscriptions removed", timeout: 3.0) {
            self.loadSub(a1.objectID) == nil && self.loadSub(a2.objectID) == nil
        }

        let remainsForUser2: Int = performSync(viewContext) {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: Constants.EntityNames.subscribe)
            fr.predicate = NSPredicate(format: "userTag == %@", "user-2")
            return (try? self.viewContext.count(for: fr)) ?? 0
        }

        XCTAssertNil(loadSub(a1.objectID))
        XCTAssertNil(loadSub(a2.objectID))
        XCTAssertEqual(remainsForUser2, 1)
    }

    /// test_5: processSubscriptions returns true when no subscriptions
    func test_5_processSubscriptions_returns_true_when_no_subscriptions() throws {
        seedConfigToSDKStore(rToken: "user-1")

        let exp = expectation(description: "no subs -> true")
        sut.processSubscriptions(context: viewContext) { completed in
            XCTAssertTrue(completed)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
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

        performSync(viewContext) {
            self.viewContext.delete(s)
            try? self.viewContext.save()
        }

        sut.perObjectBehavior[id] = .retry

        let exp = expectation(description: "invalid id -> completed")
        sut.signAll(context: viewContext, subscriptions: [id]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("no subscriptions", timeout: 3.0) { self.countSubs() == 0 }
        XCTAssertEqual(countSubs(), 0)
    }

    /// test_8: signAll retry with wrong type objectID deletes and completes
    func test_8_signAll_retry_with_wrong_type_objectID_deletes_and_completes() throws {
        _ = try makeConfig(rToken: "T")
        let cfg = try makeConfig(url: "https://api", rToken: "T2")
        let id = cfg.objectID

        sut.perObjectBehavior[id] = .retry

        let exp = expectation(description: "wrong type -> deleted & completed")
        sut.signAll(context: viewContext, subscriptions: [id]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("config deleted", timeout: 3.0) {
            self.performSync(self.viewContext) {
                (try? self.viewContext.existingObject(with: id)) == nil
            }
        }

        let exists: Bool = performSync(viewContext) {
            (try? self.viewContext.existingObject(with: id)) != nil
        }
        XCTAssertFalse(exists)
    }

    /// test_9: signAll success saves current token and deletes subscription
    func test_9_signAll_success_saves_current_token_and_deletes_subscription() throws {
        seedConfigToSDKStore(rToken: "user-1")
        let s = try makeSub(userTag: "user-1")

        sut.defaultBehavior = .success

        StoredVariablesManager.shared.clearSavedToken()
        StoredVariablesManager.shared.clearManualToken()

        let exp = expectation(description: "done")
        sut.signAll(context: viewContext, subscriptions: [s.objectID]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("subscription deleted", timeout: 3.0) { self.loadSub(s.objectID) == nil }

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.token, "TEST-APNS-TOKEN")
    }

    /// test_10: signAll error deletes subscription and continues chain
    func test_10_signAll_error_deletes_subscription_and_continues_chain() throws {
        seedConfigToSDKStore(rToken: "user-1")
        let s1 = try makeSub(userTag: "user-1", time: 1)
        let s2 = try makeSub(userTag: "user-1", time: 2)

        sut.perObjectBehavior[s1.objectID] = .error
        sut.perObjectBehavior[s2.objectID] = .success

        StoredVariablesManager.shared.clearSavedToken()
        StoredVariablesManager.shared.clearManualToken()

        let exp = expectation(description: "done")
        sut.signAll(context: viewContext, subscriptions: [s1.objectID, s2.objectID]) { retryNeeded in
            XCTAssertFalse(retryNeeded)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("both subscriptions deleted", timeout: 3.0) {
            self.loadSub(s1.objectID) == nil && self.loadSub(s2.objectID) == nil
        }
        XCTAssertEqual(countSubs(), 0)

        let saved = StoredVariablesManager.shared.getSavedToken()
        XCTAssertNotNil(saved)
        XCTAssertEqual(saved?.token, "TEST-APNS-TOKEN")
    }

    /// test_11: signAll success but current token is nil stops with retry and does not delete
    func test_11_signAll_success_but_current_token_is_nil_stops_with_retry_and_does_not_delete() throws {
        seedConfigToSDKStore(rToken: "user-1")
        let s = try makeSub(userTag: "user-1", retryCount: 0, maxRetryCount: 3)

        TokenManager.shared.apnsProvider = nil
        TokenManager.shared.fcmProvider = nil
        TokenManager.shared.hmsProvider = nil

        sut.defaultBehavior = .success

        let exp = expectation(description: "done")
        sut.signAll(context: viewContext, subscriptions: [s.objectID]) { retryNeeded in
            XCTAssertTrue(retryNeeded)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        waitUntil("subscription still exists", timeout: 3.0) { self.loadSub(s.objectID) != nil }
        XCTAssertEqual(countSubs(), 1)
    }
}

