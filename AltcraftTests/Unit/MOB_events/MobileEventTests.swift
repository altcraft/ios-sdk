//
//  MobileEventTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
* MobileEventTests
*
* Positive scenarios:
* - test_1: PartsFactory.createMobileEventParts → includes required text fields and optional JSON/text parts when present.
* - test_2: retryLimit → increments retryCount until max, then deletes entity.
* - test_3: clearOldMobileEvents → deletes oldest events when threshold is exceeded.
* - test_4: buildMobileEventURL → appends all expected query items to base URL.
* - test_5: createMobileEventRequest → builds valid POST multipart request with auth header.
* - test_6: getAllMobileEventsByTag → filters by userTag and returns events ordered by time.
* - test_7: retryLimit with invalid objectID → returns true when objectID is invalid.
* - test_8: RequestManager.responseProcessing → maps status codes to appropriate event types.
*
*/
final class MobileEventTests: IsolatedTestCase {

    private func makeMobileEventEntity() throws -> MobileEventEntity {
        guard let entity = NSEntityDescription.entity(
            forEntityName: Constants.EntityNames.mobileEventEntity,
            in: viewContext
        ) else {
            XCTFail("Failed to resolve NSEntityDescription for MobileEventEntity")
            throw NSError(
                domain: "MobileEventTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve NSEntityDescription for MobileEventEntity"]
            )
        }

        return MobileEventEntity(entity: entity, insertInto: viewContext)
    }

    @discardableResult
    private func makeEvent(
        id: String = UUID().uuidString,
        tz: Int16 = 180,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        aci: String? = "client-123",
        name: String? = "open",
        payload: [String: Any?]? = ["a": 1, "b": "x"],
        matching: [String: Any?]? = ["m": true],
        profile: [String: Any?]? = ["age": 30],
        smid: String? = "SMID-42",
        matchingType: String? = "push_sub",
        utm: UTM? = UTM(
            campaign: "camp",
            content: "cont",
            keyword: "kw",
            medium: "med",
            source: "src",
            temp: "tmp"
        )
    ) throws -> MobileEventEntity {
        var result: MobileEventEntity?
        var thrownError: Error?

        viewContext.performAndWait {
            do {
                let event = try makeMobileEventEntity()
                event.requestId = id
                event.userTag = "user-1"
                event.timeZone = tz
                event.time = time
                event.sid = "pixel-777"
                event.altcraftClientID = aci
                event.eventName = name
                event.payload = encodeAnyMap(payload)
                event.matching = encodeAnyMap(matching)
                event.profileFields = encodeAnyMap(profile)
                event.subscription = nil
                event.sendMessageId = smid
                event.retryCount = 0
                event.maxRetryCount = 2
                event.matchingType = matchingType
                event.utmTags = encodeUTM(utm)

                try viewContext.save()
                result = event
            } catch {
                thrownError = error
            }
        }

        if let thrownError {
            throw thrownError
        }

        return result!
    }

    /// test_1: PartsFactory.createMobileEventParts includes required text fields and optional JSON/text parts
    func test_1_parts_factory_includes_required_and_optional_fields() throws {
        let event = try makeEvent(tz: 90)
        let parts = PartsFactory.createMobileEventParts(from: event)

        func hasText(name: String, value: String) -> Bool {
            parts.contains {
                $0.name == name &&
                String(data: $0.data, encoding: .utf8) == value &&
                $0.filename == nil
            }
        }

        func hasJSON(name: String) -> Bool {
            parts.contains {
                $0.name == name &&
                $0.mime.hasPrefix("application/json")
            }
        }

        XCTAssertTrue(hasText(name: Constants.MobileEvents.TIME_ZONE, value: "90"))
        XCTAssertTrue(parts.contains(where: { $0.name == Constants.MobileEvents.TIME_MOB }))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.ALTCRAFT_CLIENT_ID, value: "client-123"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.MOB_EVENT_NAME, value: "open"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.MATCHING_TYPE, value: "push_sub"))

        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_CAMPAIGN, value: "camp"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_CONTENT, value: "cont"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_KEYWORD, value: "kw"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_MEDIUM, value: "med"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_SOURCE, value: "src"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_TEMP, value: "tmp"))

        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.PAYLOAD))
        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.MATCHING_MOB))
        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.PROFILE_FIELDS_MOB))
        XCTAssertTrue(parts.contains(where: { $0.name == Constants.MobileEvents.SMID_MOB }))
    }

    /// test_2: retryLimit increments retryCount until max and then deletes entity
    func test_2_retryLimit_increments_and_deletes_on_max() async throws {
        let event = try makeEvent()
        let objectID = event.objectID

        let firstResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertFalse(firstResult)

        let firstFetch = try viewContext.existingObject(with: objectID) as? MobileEventEntity
        XCTAssertEqual(firstFetch?.retryCount, 1)

        let secondResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertFalse(secondResult)

        let secondFetch = try viewContext.existingObject(with: objectID) as? MobileEventEntity
        XCTAssertEqual(secondFetch?.retryCount, 2)

        let thirdResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertTrue(thirdResult)

        let request = NSFetchRequest<MobileEventEntity>(
            entityName: Constants.EntityNames.mobileEventEntity
        )
        let all = try viewContext.fetch(request)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_3: clearOldMobileEvents keeps threshold count logic and deletes oldest records
    func test_3_clearOldMobileEvents_keeps_threshold_and_deletes_oldest() async throws {
        for index in 0..<10 {
            let time = Int64(1_700_000_000_000 + (index * 1000))
            _ = try makeEvent(time: time, name: "e\(index)")
        }

        let beforeRequest: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        let beforeCleanup = try viewContext.fetch(beforeRequest)
        let beforeCleanupCount = beforeCleanup.count

        await clearOldMobileEvents(
            context: viewContext,
            threshold: 6,
            purgeCount: 3
        )

        let request: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]

        let left = try viewContext.fetch(request)
        let expectedCount = beforeCleanupCount > 6 ? beforeCleanupCount - 3 : beforeCleanupCount
        XCTAssertEqual(left.count, expectedCount)

        let names = Set(left.compactMap { $0.eventName })
        XCTAssertFalse(names.contains("e0"))
        XCTAssertFalse(names.contains("e1"))
        XCTAssertFalse(names.contains("e2"))
    }

    /// test_4: buildMobileEventURL appends expected query params to base URL
    func test_4_build_mobile_event_url_appends_all_expected_query_items() {
        let baseURL = "https://api.altcraft.test/mob"
        let url = buildMobileEventURL(
            baseURLString: baseURL,
            sid: "SID-1",
            tracker: "px",
            type: "open",
            version: "2"
        )

        XCTAssertNotNil(url)

        let components = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        func value(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        XCTAssertEqual(value("i"), "SID-1")
        XCTAssertEqual(value("tr"), "px")
        XCTAssertEqual(value("t"), "open")
        XCTAssertEqual(value("v"), "2")
    }

    /// test_5: createMobileEventRequest builds valid POST multipart request with Authorization header
    func test_5_create_mobile_event_request_builds_valid_multipart_request() {
        let data = MobileEventRequestData(
            url: "https://api.altcraft.test/mob",
            requestId: "RID-\(UUID().uuidString)",
            sid: "SID-9",
            eventName: "open",
            parts: [
                Part(
                    name: Constants.MobileEvents.MOB_EVENT_NAME,
                    data: Data("open".utf8),
                    mime: "text/plain; charset=utf-8",
                    filename: nil
                )
            ],
            authHeader: "Bearer token"
        )

        let request = createMobileEventRequest(data: data)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(
            request?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization),
            "Bearer token"
        )

        let contentType = request?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        XCTAssertNotNil(request?.httpBody)

        let components = URLComponents(url: request!.url!, resolvingAgainstBaseURL: false)
        let names = Set((components?.queryItems ?? []).map { $0.name })
        XCTAssertTrue(names.isSuperset(of: ["i", "tr", "t", "v"]))
    }

    /// test_6: getAllMobileEventsByTag filters by userTag and orders by time
    func test_6_get_all_mobile_events_by_tag_filters_by_user_tag_and_orders_by_time() async throws {
        func add(_ tag: String, _ time: Int64, _ name: String) throws {
            let event = try makeMobileEventEntity()
            event.requestId = UUID().uuidString
            event.userTag = tag
            event.timeZone = 0
            event.time = time
            event.sid = "sid"
            event.eventName = name
            event.retryCount = 0
            event.maxRetryCount = 3
        }

        try add("A", 1_700_000_000_001, "a1")
        try add("B", 1_700_000_000_000, "b0")
        try add("A", 1_700_000_000_003, "a3")
        try add("A", 1_700_000_000_002, "a2")
        try viewContext.save()

        let ids = await getAllMobileEventsByTag(context: viewContext, userTag: "A")
        XCTAssertEqual(ids.count, 3)

        let context = viewContext
        var names: [String] = []

        context.performAndWait {
            for objectID in ids {
                if let object = try? context.existingObject(with: objectID) as? MobileEventEntity {
                    names.append(object.eventName ?? "")
                }
            }
        }

        XCTAssertEqual(names, ["a1", "a2", "a3"])
    }

    /// test_7: retryLimit returns true for an invalid objectID
    func test_7_retry_limit_returns_true_for_invalid_object_id() async throws {
        let event = try makeEvent()
        let objectID = event.objectID
        let context = viewContext

        var deletionError: Error?

        context.performAndWait {
            do {
                let object = try context.existingObject(with: objectID)
                context.delete(object)
                try context.save()
            } catch {
                deletionError = error
            }
        }

        if let deletionError {
            throw deletionError
        }

        let result = await retryLimit(context: context, objectID: objectID)
        XCTAssertTrue(result)
    }

    /// test_8: RequestManager.responseProcessing maps HTTP status codes to event types correctly
    func test_8_response_processing_maps_status_codes_to_event_types_and_payload() {
        let manager = RequestManager()
        let url = URL(string: "https://example.com")!

        func response(_ code: Int) -> HTTPURLResponse {
            HTTPURLResponse(
                url: url,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
        }

        let body = """
        {"result":"ok","detail":"unit"}
        """.data(using: .utf8)

        let ok = manager.responseProcessing(
            response: response(200),
            data: body,
            requestName: "mobileEvent",
            name: "open"
        )

        let serverError = manager.responseProcessing(
            response: response(503),
            data: body,
            requestName: "mobileEvent",
            name: "open"
        )

        let clientError = manager.responseProcessing(
            response: response(404),
            data: body,
            requestName: "mobileEvent",
            name: "open"
        )

        XCTAssertTrue(type(of: ok) == Event.self)
        XCTAssertFalse(type(of: ok) == ErrorEvent.self)
        XCTAssertTrue(type(of: serverError) == RetryEvent.self)
        XCTAssertTrue(type(of: clientError) == ErrorEvent.self)
        XCTAssertFalse(type(of: clientError) == RetryEvent.self)
    }
}
