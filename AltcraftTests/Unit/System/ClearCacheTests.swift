//
//  ClearCacheTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * ClearCacheTests
 *
 * Positive scenarios:
 *  - test_1: clearCache resets counters, tokens, emits event and wipes database.
 *  - test_2: clearCache when DB error flag is true does nothing and does not call completion.
 */
final class ClearCacheTests: XCTestCase {

    private let container = CoreDataManager.shared.persistentContainer

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] ev in self?.events.append(ev) } }
        func stop() { SDKEvents.shared.unsubscribe() }
        func fresh(since n: Int) -> [Event] { Array(events.dropFirst(n)) }
    }

    override func setUp() {
        super.setUp()
        wipeSDK([
            Constants.EntityNames.config,
            Constants.EntityNames.subscribe,
            Constants.EntityNames.pushEvent,
            Constants.EntityNames.mobileEvent
        ])
        
        StoredVariablesManager.shared.setGroupsName(value: "AltcraftTests.ClearCache")
    }

    override func tearDown() {
        wipeSDK([
            Constants.EntityNames.config,
            Constants.EntityNames.subscribe,
            Constants.EntityNames.pushEvent,
            Constants.EntityNames.mobileEvent
        ])
        super.tearDown()
    }

    private func withBG(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.performAndWait { block(ctx) }
    }

    private func count(_ entity: String) -> Int {
        var n = 0
        withBG { ctx in
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            n = (try? ctx.count(for: fr)) ?? 0
        }
        return n
    }

    private func wipeSDK(_ names: [String]) {
        withBG { ctx in
            for name in names {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                fr.includesPropertyValues = false
                if let list = try? ctx.fetch(fr) as? [NSManagedObject] {
                    list.forEach { ctx.delete($0) }
                }
            }
            if ctx.hasChanges { try? ctx.save() }
        }
    }

    private func seedAllEntities() {
        withBG { ctx in
            let cfg = ConfigurationEntity(context: ctx)
            cfg.url = "https://api"
            cfg.rToken = "r"
            for i in 0..<2 {
                let s = SubscribeEntity(context: ctx)
                s.userTag = "u"
                s.status = "subscribed"
                s.sync = 1
                s.time = Int64(1_700_000_000_000 + i)
                s.retryCount = 0
                s.maxRetryCount = 3

                let pe = PushEventEntity(context: ctx)
                pe.uid = "uid-\(i)"
                pe.type = Constants.PushEvents.delivery
                pe.time = Int64(1_700_000_000_500 + i)
                pe.retryCount = 0
                pe.maxRetryCount = 3

                let me = MobileEventEntity(context: ctx)
                me.userTag = "u"
                me.sid = "sid-\(i)"
                me.eventName = "open"
                me.time = Int64(1_700_000_001_000 + i)
                me.timeZone = 180
                me.retryCount = 0
                me.maxRetryCount = 3
            }
            try? ctx.save()
        }
    }

    /// test_1: clearCache resets counters, tokens, emits event and wipes database
    func test_1_clearCache_resets_counters_tokens_emitsEvent_and_wipesDB() {
        seedAllEntities()
        XCTAssertEqual(count(Constants.EntityNames.config), 1)
        XCTAssertEqual(count(Constants.EntityNames.subscribe), 2)
        XCTAssertEqual(count(Constants.EntityNames.pushEvent), 2)
        XCTAssertEqual(count(Constants.EntityNames.mobileEvent), 2)

        subRetryCount = 10
        updateRetryCount = 11
        pushEventRetryCount = 12
        mobileEventRetryCount = 13

        StoredVariablesManager.shared.setPushToken(provider: "ios-apns", token: "manual-token")
        StoredVariablesManager.shared.setCurrentToken(provider: "ios-apns", token: "saved-token")
        TokenUpdate.shared.currentToken = TokenData(provider: "ios-apns", token: "temp-token")
        TokenManager.shared.tokens.ts_append("t1")
        TokenManager.shared.tokens.ts_append("t2")

        let spy = EventSpy(); spy.start()
        defer { spy.stop() }
        let before = spy.events.count

        let exp = expectation(description: "clearCache completion")
        clearCache { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)

        XCTAssertEqual(count(Constants.EntityNames.config), 0)
        XCTAssertEqual(count(Constants.EntityNames.subscribe), 0)
        XCTAssertEqual(count(Constants.EntityNames.pushEvent), 0)
        XCTAssertEqual(count(Constants.EntityNames.mobileEvent), 0)

        XCTAssertEqual(subRetryCount, 0)
        XCTAssertEqual(updateRetryCount, 0)
        XCTAssertEqual(pushEventRetryCount, 0)
        XCTAssertEqual(mobileEventRetryCount, 0)

        XCTAssertNil(StoredVariablesManager.shared.getManualToken())
        XCTAssertNil(StoredVariablesManager.shared.getSavedToken())
        XCTAssertNil(TokenUpdate.shared.currentToken)

        XCTAssertNil(TokenManager.shared.tokens.ts_last() ?? (nil as String?))

        let fresh = spy.fresh(since: before)
        let hasClearedEvent = fresh.contains { normalizeFunc($0.function) == "clearCache" }
        XCTAssertTrue(hasClearedEvent, "Expected sdkCleared event from clearCache()")
    }

//    /// test_2: clearCache when DB error flag is true does nothing and does not call completion
//    func test_2_clearCache_whenDbErrorFlag_true_doesNothing_and_doesNotCallCompletion() {
//        StoredVariablesManager.shared.setCritDB(value: true)
//
//        seedAllEntities()
//        subRetryCount = 3
//        TokenManager.shared.tokens.ts_append("x")
//        TokenUpdate.shared.currentToken = TokenData(provider: "ios-apns", token: "y")
//
//        let exp = expectation(description: "no-callback")
//        exp.isInverted = true
//        clearCache { exp.fulfill() }
//        wait(for: [exp], timeout: 0.3)
//
//        XCTAssertEqual(count(Constants.EntityNames.config), 1)
//        XCTAssertEqual(subRetryCount, 3)
//
//        let lastBeforeClear = TokenManager.shared.tokens.ts_last() ?? (nil as String?)
//        XCTAssertEqual(lastBeforeClear, "x")
//        XCTAssertEqual(TokenUpdate.shared.currentToken?.token, "y")
//
//        StoredVariablesManager.shared.setCritDB(value: false)
//    }

    private func normalizeFunc(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") { return String(raw[..<idx]) }
        return raw.hasSuffix("()") ? String(raw.dropLast(2)) : raw
    }
}
