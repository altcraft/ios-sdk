//
//  ClearCacheTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * ClearCacheTests
 *
 * Positive scenarios:
 *  - test_1: clearCache → resets retry counters, clears persisted token data,
 *            emits event and wipes database.
 *  - test_2: clearCache when DB error flag is true → does not wipe database,
 *            emits error event and still calls completion.
 *
 */
final class ClearCacheTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private final class EventSpy {
        private let lock = NSLock()
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] event in
                self?.lock.lock()
                self?.events.append(event)
                self?.lock.unlock()
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }

        func fresh(since index: Int) -> [Event] {
            lock.lock()
            defer { lock.unlock() }
            return Array(events.dropFirst(index))
        }

        func count() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return events.count
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        wipeSDK([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.pushEventEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ])

        StoredVariablesManager.shared.setGroupsName(
            value: "AltcraftTests.ClearCache.\(UUID().uuidString)"
        )
        StoredVariablesManager.shared.setCritDB(value: false)
    }

    override func tearDownWithError() throws {
        wipeSDK([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.pushEventEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ])

        StoredVariablesManager.shared.setCritDB(value: false)

        try super.tearDownWithError()
    }

    override func setUp() async throws {
        try await super.setUp()
        await StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
        await TokenManager.shared.clearTokens()
        await TokenUpdate.shared.test_token_update_set_current_token(nil)
    }

    override func tearDown() async throws {
        await StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
        await TokenManager.shared.clearTokens()
        await TokenUpdate.shared.test_token_update_set_current_token(nil)
        try await super.tearDown()
    }

    private func withBG(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = newBGContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.performAndWait {
            block(context)
        }
    }

    private func count(_ entity: String) -> Int {
        var result = 0

        withBG { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            result = (try? context.count(for: request)) ?? 0
        }

        return result
    }

    private func wipeSDK(_ names: [String]) {
        withBG { context in
            for name in names {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                request.includesPropertyValues = false

                if let list = try? context.fetch(request) as? [NSManagedObject] {
                    list.forEach { context.delete($0) }
                }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    private func seedAllEntities() {
        withBG { context in
            let configuration = ConfigurationEntity(context: context)
            configuration.url = "https://api"
            configuration.rToken = "r"

            for index in 0..<2 {
                let subscribe = SubscribeEntity(context: context)
                subscribe.userTag = "u"
                subscribe.status = "subscribed"
                subscribe.sync = 1
                subscribe.time = Int64(1_700_000_000_000 + index)
                subscribe.retryCount = 0
                subscribe.maxRetryCount = 3

                let pushEvent = PushEventEntity(context: context)
                pushEvent.uid = "uid-\(index)"
                pushEvent.type = Constants.PushEvents.delivery
                pushEvent.time = Int64(1_700_000_000_500 + index)
                pushEvent.retryCount = 0
                pushEvent.maxRetryCount = 3

                let mobileEvent = MobileEventEntity(context: context)
                mobileEvent.userTag = "u"
                mobileEvent.sid = "sid-\(index)"
                mobileEvent.eventName = "open"
                mobileEvent.time = Int64(1_700_000_001_000 + index)
                mobileEvent.timeZone = 180
                mobileEvent.retryCount = 0
                mobileEvent.maxRetryCount = 3

                let profileUpdate = ProfileUpdateEntity(context: context)
                profileUpdate.userTag = "u"
                profileUpdate.requestId = "rid-\(index)"
                profileUpdate.time = Int64(1_700_000_002_000 + index)
                profileUpdate.profileFields = Data("{\"k\":\(index)}".utf8)
                profileUpdate.skipTriggers = (index % 2 == 0)
                profileUpdate.retryCount = 0
                profileUpdate.maxRetryCount = 15
            }

            try? context.save()
        }
    }

    private func normalizeFunc(_ raw: String?) -> String {
        guard let raw else { return "" }

        if let index = raw.firstIndex(of: "(") {
            return String(raw[..<index])
        }

        return raw.hasSuffix("()") ? String(raw.dropLast(2)) : raw
    }

    /// test_1: clearCache resets retry counters, clears persisted token data, emits event and wipes database
    func test_1_clearCache_resetsRetryCounters_clearsPersistedTokenData_emitsEvent_andWipesDatabase() async {
        seedAllEntities()

        XCTAssertEqual(count(Constants.EntityNames.configurationEntity), 1)
        XCTAssertEqual(count(Constants.EntityNames.subscribeEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.pushEventEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.mobileEventEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 2)

        RetryCounters.shared.increment(RetryKey.subscribe)
        RetryCounters.shared.increment(RetryKey.subscribe)

        RetryCounters.shared.increment(RetryKey.tokenUpdate)
        RetryCounters.shared.increment(RetryKey.tokenUpdate)
        RetryCounters.shared.increment(RetryKey.tokenUpdate)

        RetryCounters.shared.increment(RetryKey.pushEvent)
        RetryCounters.shared.increment(RetryKey.mobileEvent)
        RetryCounters.shared.increment(RetryKey.profileUpdate)

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.apns,
            token: "manual-token"
        )
        StoredVariablesManager.shared.setCurrentToken(
            provider: Constants.ProviderName.apns,
            token: "saved-token"
        )

        await TokenUpdate.shared.test_token_update_set_current_token(
            TokenData(provider: Constants.ProviderName.apns, token: "temp-token")
        )

        await TokenManager.shared.test_append_token("t1")
        await TokenManager.shared.test_append_token("t2")

        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count()

        let exp = expectation(description: "clearCache completion")
        clearCache {
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 2.0)

        XCTAssertEqual(count(Constants.EntityNames.configurationEntity), 0)
        XCTAssertEqual(count(Constants.EntityNames.subscribeEntity), 0)
        XCTAssertEqual(count(Constants.EntityNames.pushEventEntity), 0)
        XCTAssertEqual(count(Constants.EntityNames.mobileEventEntity), 0)
        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 0)

        XCTAssertEqual(RetryCounters.shared.get(RetryKey.subscribe), 0)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.tokenUpdate), 0)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.pushEvent), 0)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.mobileEvent), 0)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.profileUpdate), 0)

        let manualToken = await StoredVariablesManager.shared.getManualToken()
        XCTAssertNil(manualToken)

        XCTAssertNil(StoredVariablesManager.shared.getSavedToken())

        let tokenHistory = await TokenManager.shared.test_tokens_snapshot()
        XCTAssertTrue(tokenHistory.isEmpty)

        let fresh = spy.fresh(since: before)
        let hasClearedEvent = fresh.contains {
            normalizeFunc($0.function) == "clearCache"
        }

        XCTAssertTrue(hasClearedEvent, "Expected sdkCleared event from clearCache()")
    }

    /// test_2: clearCache when DB error flag is true does not wipe database, emits error event and still calls completion
    func test_2_clearCache_whenDbErrorFlagIsTrue_doesNotWipeDatabase_emitsErrorEvent_andStillCallsCompletion() async {
        seedAllEntities()

        RetryCounters.shared.increment(RetryKey.subscribe)
        RetryCounters.shared.increment(RetryKey.tokenUpdate)
        RetryCounters.shared.increment(RetryKey.pushEvent)
        RetryCounters.shared.increment(RetryKey.mobileEvent)
        RetryCounters.shared.increment(RetryKey.profileUpdate)

        await StoredVariablesManager.shared.setPushToken(
            provider: Constants.ProviderName.apns,
            token: "manual-token"
        )
        StoredVariablesManager.shared.setCurrentToken(
            provider: Constants.ProviderName.apns,
            token: "saved-token"
        )

        await TokenUpdate.shared.test_token_update_set_current_token(
            TokenData(provider: Constants.ProviderName.apns, token: "temp-token")
        )

        await TokenManager.shared.test_append_token("t1")

        StoredVariablesManager.shared.setCritDB(value: true)

        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let before = spy.count()

        let exp = expectation(description: "clearCache completion")
        clearCache {
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 2.0)

        XCTAssertEqual(count(Constants.EntityNames.configurationEntity), 1)
        XCTAssertEqual(count(Constants.EntityNames.subscribeEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.pushEventEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.mobileEventEntity), 2)
        XCTAssertEqual(count(Constants.EntityNames.profileUpdateEntity), 2)

        XCTAssertEqual(RetryCounters.shared.get(RetryKey.subscribe), 1)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.tokenUpdate), 1)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.pushEvent), 1)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.mobileEvent), 1)
        XCTAssertEqual(RetryCounters.shared.get(RetryKey.profileUpdate), 1)

        let manualToken = await StoredVariablesManager.shared.getManualToken()
        XCTAssertEqual(manualToken?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(manualToken?.token, "manual-token")

        let savedToken = StoredVariablesManager.shared.getSavedToken()
        XCTAssertEqual(savedToken?.provider, Constants.ProviderName.apns)
        XCTAssertEqual(savedToken?.token, "saved-token")

        let tokenHistory = await TokenManager.shared.test_tokens_snapshot()
        XCTAssertEqual(tokenHistory, ["t1"])

        let fresh = spy.fresh(since: before)
        let hasCoreDataErrorEvent = fresh.contains {
            normalizeFunc($0.function) == "clearCache"
        }

        XCTAssertTrue(hasCoreDataErrorEvent, "Expected coreDataError event from clearCache()")
    }
}
