//
//  PublicPushEventFunctionsTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import UserNotifications
import CoreData
@testable import Altcraft

/**
 * PublicPushEventFunctionsTests (iOS 13 compatible)
 *
 * Coverage (concise, explicit test names):
 *  - test_1_deliveryEvent_nonAltcraft_silentlyReturns_noEvents
 *  - test_2_openEvent_nonAltcraft_silentlyReturns_noEvents
 *  - test_3_createPushEvent_missingUid_emitsErrorEvent_uidIsNil
 *  - test_4_addPushEventEntity_persists_defaults_andReturnsEntity
 *
 * Notes:
 *  - We capture SDKEvents with a spy to assert emissions/non-emissions.
 *  - For non-Altcraft requests, we construct an empty userInfo; `isAltcraftPush` is expected to return false.
 *  - Core Data checks in test_4 run against the production persistent container (no seams).
 */
final class PublicPushEventFunctionsTests: XCTestCase {

    // MARK: - Event Spy

    private final class EventSpy {
        private(set) var events: [Event] = []

        func start() {
            SDKEvents.shared.subscribe { [weak self] ev in
                self?.events.append(ev)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }
    }

    // MARK: - Helpers

    private func makeRequest(identifier: String = "test", userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    /// Safely normalizes function names that may include parameter lists or trailing "()"
    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") {
            return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.hasSuffix("()") {
            return String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tests

    /// test_1_deliveryEvent_nonAltcraft_silentlyReturns_noEvents
    func test_1_deliveryEvent_nonAltcraft_silentlyReturns_noEvents() {
        // Given: non-Altcraft request (empty userInfo is expected to be treated as non-Altcraft)
        let req = makeRequest(userInfo: [:])
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        // When
        PublicPushEventFunctions.shared.deliveryEvent(from: req)

        // Then: no events should be emitted at all
        XCTAssertTrue(spy.events.isEmpty, "No events must be emitted for non-Altcraft notifications")
    }

    /// test_2_openEvent_nonAltcraft_silentlyReturns_noEvents
    func test_2_openEvent_nonAltcraft_silentlyReturns_noEvents() {
        // Given
        let req = makeRequest(userInfo: [:])
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        // When
        PublicPushEventFunctions.shared.openEvent(from: req)

        // Then
        XCTAssertTrue(spy.events.isEmpty, "No events must be emitted for non-Altcraft notifications")
    }

    /// test_3_createPushEvent_missingUid_emitsErrorEvent_uidIsNil
    func test_3_createPushEvent_missingUid_emitsErrorEvent_uidIsNil() {
        // Given: userInfo without required uid
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        // When: call internal flow directly (doesn't depend on Altcraft detector)
        PushEvent.shared.createPushEvent(userInfo: [:], type: Constants.PushEvents.delivery)

        // Then: expect ErrorEvent from createPushEvent (uidIsNil)
        let hasErrorFromCreate = spy.events.contains {
            ($0 is ErrorEvent) && normalizeFunctionName($0.function) == "createPushEvent"
        }
        XCTAssertTrue(hasErrorFromCreate, "Expected ErrorEvent(uidIsNil) emitted from createPushEvent")
    }

    /// test_4_addPushEventEntity_persists_defaults_andReturnsEntity
    func test_4_addPushEventEntity_persists_defaults_andReturnsEntity() {
        // Given: a background context from production stack
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.newBackgroundContext()

        let uid = "UID-\(UUID().uuidString)"
        let type = Constants.PushEvents.delivery

        let exp = expectation(description: "addPushEventEntity completion")
        var created: PushEventEntity?

        // When
        addPushEventEntity(context: ctx, uid: uid, type: type) { entity in
            created = entity
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)

        // Then
        XCTAssertNotNil(created, "Entity should be created")
        guard let e = created else { return }

        // Check persisted fields and defaults
        XCTAssertEqual(e.uid, uid)
        XCTAssertEqual(e.type, type)
        XCTAssertEqual(e.retryCount, 0)
        XCTAssertEqual(e.maxRetryCount, 15)

        // "time" should be close to now (within ±5s)
        let now = Int64(Date().timeIntervalSince1970)
        XCTAssertGreaterThanOrEqual(e.time, now - 5)
        XCTAssertLessThanOrEqual(e.time, now + 5)

        // Verify saved state by refetching from the same context
        var fetched: [PushEventEntity] = []
        ctx.performAndWait {
            let fr: NSFetchRequest<PushEventEntity> = PushEventEntity.fetchRequest()
            fr.predicate = NSPredicate(format: "uid == %@", uid)
            fetched = (try? ctx.fetch(fr)) ?? []
        }
        XCTAssertEqual(fetched.count, 1, "Exactly one entity with given uid must be stored")
    }
}

