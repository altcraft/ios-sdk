//
//  ClearingDbTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.


import XCTest
import CoreData
@testable import Altcraft

/**
 * ClearingDbTests (isolated against SDK Core Data container)
 *
 * Coverage:
 *  - test_1_deleteEntity_invalidName_returnsFalse_and_emitsError
 *  - test_2_deleteEntity_removes_all_rows_for_valid_entity
 *  - test_3_deleteAllEntitiesFromDb_wipes_all_predefined_entities
 *  - test_4_deleteEntity_on_empty_table_returnsTrue
 *
 * Notes:
 *  - Seeds and counts use CoreDataManager.shared.persistentContainer directly to match production code paths.
 *  - Each test wipes affected entities before and after to remain isolated.
 */
final class ClearingDbTests: XCTestCase {

    private let container = CoreDataManager.shared.persistentContainer

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] ev in self?.events.append(ev) } }
        func stop()  { SDKEvents.shared.unsubscribe() }
        func fresh(since n: Int) -> [Event] { Array(events.dropFirst(n)) }
    }

    override func setUp() {
        super.setUp()
        sdkWipe([
            Constants.EntityNames.config,
            Constants.EntityNames.subscribe,
            Constants.EntityNames.pushEvent,
            Constants.EntityNames.mobileEvent
        ])
    }

    override func tearDown() {
        sdkWipe([
            Constants.EntityNames.config,
            Constants.EntityNames.subscribe,
            Constants.EntityNames.pushEvent,
            Constants.EntityNames.mobileEvent
        ])
        super.tearDown()
    }

    private func sdkBG(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.performAndWait { block(ctx) }
    }

    private func sdkCount(_ entityName: String) -> Int {
        var n = 0
        sdkBG { ctx in
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            n = (try? ctx.count(for: fr)) ?? 0
        }
        return n
    }

    private func sdkWipe(_ entityNames: [String]) {
        sdkBG { ctx in
            entityNames.forEach { name in
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                fr.includesPropertyValues = false
                if let list = try? ctx.fetch(fr) as? [NSManagedObject] { list.forEach { ctx.delete($0) } }
            }
            if ctx.hasChanges { try? ctx.save() }
        }
    }

    private func seedSubscribe(count: Int) {
        guard count > 0 else { return }
        sdkBG { ctx in
            for i in 0..<count {
                let e = SubscribeEntity(context: ctx)
                e.userTag = "u"
                e.status = "subscribed"
                e.sync = 1
                e.time = Int64(1_700_000_000_000 + i)
                e.retryCount = 0
                e.maxRetryCount = 3
            }
            try? ctx.save()
        }
    }

    private func seedPushEvents(count: Int) {
        guard count > 0 else { return }
        sdkBG { ctx in
            for i in 0..<count {
                let e = PushEventEntity(context: ctx)
                e.uid = "uid-\(i)"
                e.type = Constants.PushEvents.delivery
                e.time = Int64(1_700_000_000_000 + i)
                e.retryCount = 0
                e.maxRetryCount = 3
            }
            try? ctx.save()
        }
    }

    private func seedMobileEvents(count: Int) {
        guard count > 0 else { return }
        sdkBG { ctx in
            for i in 0..<count {
                let e = MobileEventEntity(context: ctx)
                e.userTag = "u"
                e.sid = "sid-\(i)"
                e.eventName = "open"
                e.time = Int64(1_700_000_000_000 + i)
                e.timeZone = 180
                e.retryCount = 0
                e.maxRetryCount = 3
            }
            try? ctx.save()
        }
    }

    private func seedConfig() {
        sdkBG { ctx in
            let e = ConfigurationEntity(context: ctx)
            e.url = "https://api"
            e.rToken = "T"
            try? ctx.save()
        }
    }

    /// test_1_deleteEntity_invalidName_returnsFalse_and_emitsError
    func test_1_deleteEntity_invalidName_returnsFalse_and_emitsError() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }
        let before = spy.events.count

        let exp = expectation(description: "invalid entity completion")
        var success = true
        ClearingDb.shared.deleteEntity(entityName: "__nope__") {
            success = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertFalse(success)

        let fresh = spy.fresh(since: before)
        let hasError = fresh.contains { ($0 is ErrorEvent) && $0.function.contains("deleteEntity") }
        XCTAssertTrue(hasError)
    }

    /// test_2_deleteEntity_removes_all_rows_for_valid_entity
    func test_2_deleteEntity_removes_all_rows_for_valid_entity() {
        seedSubscribe(count: 3)
        XCTAssertEqual(sdkCount(Constants.EntityNames.subscribe), 3)

        let exp = expectation(description: "delete subscribe")
        var ok = false
        ClearingDb.shared.deleteEntity(entityName: Constants.EntityNames.subscribe) {
            ok = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(ok)
        XCTAssertEqual(sdkCount(Constants.EntityNames.subscribe), 0)
    }

    /// test_3_deleteAllEntitiesFromDb_wipes_all_predefined_entities
    func test_3_deleteAllEntitiesFromDb_wipes_all_predefined_entities() {
        seedConfig()
        seedSubscribe(count: 2)
        seedPushEvents(count: 2)
        seedMobileEvents(count: 2)

        XCTAssertEqual(sdkCount(Constants.EntityNames.config), 1)
        XCTAssertEqual(sdkCount(Constants.EntityNames.subscribe), 2)
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 2)
        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 2)

        let exp = expectation(description: "delete all")
        var ok = false
        ClearingDb.shared.deleteAllEntitiesFromDb {
            ok = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)

        XCTAssertTrue(ok)
        XCTAssertEqual(sdkCount(Constants.EntityNames.config), 0)
        XCTAssertEqual(sdkCount(Constants.EntityNames.subscribe), 0)
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 0)
        XCTAssertEqual(sdkCount(Constants.EntityNames.mobileEvent), 0)
    }

    /// test_4_deleteEntity_on_empty_table_returnsTrue
    func test_4_deleteEntity_on_empty_table_returnsTrue() {
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 0)

        let exp = expectation(description: "delete empty")
        var ok = false
        ClearingDb.shared.deleteEntity(entityName: Constants.EntityNames.pushEvent) {
            ok = $0
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        XCTAssertTrue(ok)
        XCTAssertEqual(sdkCount(Constants.EntityNames.pushEvent), 0)
    }
}

