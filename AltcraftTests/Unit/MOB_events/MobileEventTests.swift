//
//  MobileEventTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * MobileEventTest
 *
 * Positive scenarios:
 *  - test_1: PartsFactory.createMobileEventParts → includes required text fields and optional JSON/text parts when present.
 *  - test_2: retryLimit → increments retryCount until max, then deletes entity.
 *  - test_3: clearOldMobileEvents → deletes oldest events when threshold is exceeded.
 *  - test_4: buildMobileEventURL → appends all expected query items (i/tr/t/v) to base URL.
 *  - test_5: createMobileEventRequest → builds valid POST multipart request with auth header.
 *  - test_6: getAllMobileEventsByTag → filters by userTag and returns events ordered by time.
 *  - test_7: retryLimit with invalid objectID → returns true when objectID is invalid.
 *  - test_8: RequestManager.responseProcessing → maps status codes to appropriate event types.
 */
final class MobileEventTest: IsolatedTestCase {

    @discardableResult
    private func makeEvent(
        id: String = UUID().uuidString,
        tz: Int16 = 180,
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        aci: String? = "client-123",
        name: String? = "open",
        payload: [String: Any?]? = ["a": 1, "b": "x"],
        matching: [String: Any?]? = ["m": true],
        profile:  [String: Any?]? = ["age": 30],
        smid: String? = "SMID-42",
        matchingType: String? = "push_sub",
        utm: UTM? = UTM(campaign: "camp", content: "cont", keyword: "kw", medium: "med", source: "src", temp: "tmp")
    ) throws -> MobileEventEntity {
        let e = MobileEventEntity(context: viewContext)
        e.userTag = "user-1"
        e.timeZone = tz
        e.time = time
        e.sid = "pixel-777"
        e.altcraftClientID = aci
        e.eventName = name
        e.payload = encodeAnyMap(payload)
        e.matching = encodeAnyMap(matching)
        e.profileFields = encodeAnyMap(profile)
        e.subscription = nil
        e.sendMessageId = smid
        e.retryCount = 0
        e.maxRetryCount = 2
        e.matchingType = matchingType
        e.utmTags = encodeUTM(utm)

        try viewContext.save()
        return e
    }

    /// test_1: PartsFactory.createMobileEventParts includes required text fields and optional JSON/text parts
    func test_1_parts_factory_includes_required_and_optional_fields() throws {
        let e = try makeEvent(tz: 90)
        let parts = PartsFactory.createMobileEventParts(from: e)

        func hasText(name: String, value: String) -> Bool {
            parts.contains { $0.name == name && String(data: $0.data, encoding: .utf8) == value && $0.filename == nil }
        }
        func hasJSON(name: String) -> Bool {
            parts.contains { $0.name == name && $0.mime.hasPrefix("application/json") }
        }

        XCTAssertTrue(hasText(name: Constants.MobileEvents.TIME_ZONE, value: "90"))
        XCTAssertTrue(parts.contains(where: { $0.name == Constants.MobileEvents.TIME_MOB }))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.ALTCRAFT_CLIENT_ID, value: "client-123"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.MOB_EVENT_NAME, value: "open"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.MATCHING_TYPE, value: "push_sub"))

        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_CAMPAIGN, value: "camp"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_CONTENT,  value: "cont"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_KEYWORD,  value: "kw"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_MEDIUM,   value: "med"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_SOURCE,   value: "src"))
        XCTAssertTrue(hasText(name: Constants.MobileEvents.UTM_TEMP,     value: "tmp"))

        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.PAYLOAD))
        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.MATCHING_MOB))
        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.PROFILE_FIELDS_MOB))
        XCTAssertTrue(hasJSON(name: Constants.MobileEvents.SMID_MOB))
    }

    /// test_2: retryLimit increments retryCount until max and then deletes entity
    func test_2_retryLimit_increments_and_deletes_on_max() throws {
        let e = try makeEvent()
        let id = e.objectID

        let exp1 = expectation(description: "first increment")
        retryLimit(context: viewContext, for: id) { deleted in
            XCTAssertFalse(deleted)
            exp1.fulfill()
        }
        wait(for: [exp1], timeout: 1.0)

        let exp2 = expectation(description: "second increment")
        retryLimit(context: viewContext, for: id) { deleted in
            XCTAssertFalse(deleted)
            exp2.fulfill()
        }
        wait(for: [exp2], timeout: 1.0)

        let exp3 = expectation(description: "delete on max")
        retryLimit(context: viewContext, for: id) { deleted in
            XCTAssertTrue(deleted)
            exp3.fulfill()
        }
        wait(for: [exp3], timeout: 1.0)

        let fetch = NSFetchRequest<MobileEventEntity>(entityName: Constants.EntityNames.mobileEvent)
        let all = try viewContext.fetch(fetch)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_3: clearOldMobileEvents keeps threshold count and deletes oldest records
    func test_3_clearOldMobileEvents_keeps_threshold_and_deletes_oldest() throws {
        for i in 0..<10 {
            let time = Int64(1_700_000_000_000 + (i * 1000))
            _ = try makeEvent(time: time, name: "e\(i)")
        }

        let exp = expectation(description: "cleanup done")
        clearOldMobileEvents(context: viewContext, threshold: 6, purgeCount: 3) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        let req: NSFetchRequest<MobileEventEntity> = MobileEventEntity.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        let left = try viewContext.fetch(req)
        XCTAssertEqual(left.count, 7)
        let names = left.compactMap { $0.eventName }
        XCTAssertFalse(names.contains("e0"))
        XCTAssertFalse(names.contains("e1"))
        XCTAssertFalse(names.contains("e2"))
    }

    /// test_4: buildMobileEventURL appends expected query params (i/tr/t/v)
    func test_4_buildMobileEventURL_appends_all_expected_query_items() {
        let base = "https://api.altcraft.test/mob"
        let url = buildMobileEventURL(
            baseURLString: base,
            sid: "SID-1",
            tracker: "px",
            type: "open",
            version: "2"
        )

        XCTAssertNotNil(url)
        let comps = URLComponents(url: url!, resolvingAgainstBaseURL: false)
        let q = comps?.queryItems ?? []
        func val(_ name: String) -> String? { q.first(where: { $0.name == name })?.value }
        XCTAssertEqual(val("i"),  "SID-1")
        XCTAssertEqual(val("tr"), "px")
        XCTAssertEqual(val("t"),  "open")
        XCTAssertEqual(val("v"),  "2")
    }

    /// test_5: createMobileEventRequest builds valid POST multipart request with Authorization header
    func test_5_createMobileEventRequest_builds_valid_multipart_request() throws {
        let data = MobileEventRequestData(
            url: "https://api.altcraft.test/mob",
            requestId: "RID-\(UUID().uuidString)",
            sid: "SID-9",
            eventName: "open",
            parts: [
                Part(name: Constants.MobileEvents.MOB_EVENT_NAME,
                     data: Data("open".utf8),
                     mime: "text/plain; charset=utf-8",
                     filename: nil)
            ],
            authHeader: "Bearer token"
        )

        let request = createMobileEventRequest(data: data)
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(request?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer token")
        let ct = request?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(ct.hasPrefix("multipart/form-data; boundary="))
        XCTAssertNotNil(request?.httpBody)

        let comps = URLComponents(url: request!.url!, resolvingAgainstBaseURL: false)
        let names = Set((comps?.queryItems ?? []).map { $0.name })
        XCTAssertTrue(names.isSuperset(of: ["i", "tr", "t", "v"]))
    }

    /// test_6: getAllMobileEventsByTag filters by userTag and orders by time (FIFO)
    func test_6_getAllMobileEventsByTag_filters_by_userTag_and_orders_by_time() throws {
        func add(_ tag: String, _ time: Int64, _ name: String) throws {
            let e = MobileEventEntity(context: self.viewContext)
            e.userTag = tag
            e.timeZone = 0
            e.time = time
            e.sid = "sid"
            e.eventName = name
            e.retryCount = 0
            e.maxRetryCount = 3
        }
        try add("A", 1_700_000_000_001, "a1")
        try add("B", 1_700_000_000_000, "b0")
        try add("A", 1_700_000_000_003, "a3")
        try add("A", 1_700_000_000_002, "a2")
        try viewContext.save()

        let exp = expectation(description: "fetch A in FIFO")
        getAllMobileEventsByTag(context: viewContext, userTag: "A") { ids in
            XCTAssertEqual(ids.count, 3)

            var names: [String] = []
            self.viewContext.performAndWait {
                ids.forEach { id in
                    if let obj = try? self.viewContext.existingObject(with: id) as? MobileEventEntity {
                        names.append(obj.eventName ?? "")
                    }
                }
            }
            XCTAssertEqual(names, ["a1", "a2", "a3"])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_7: retryLimit returns true for an invalid (deleted) objectID
    func test_7_retryLimit_returns_true_for_invalid_objectID() throws {
        let e = try makeEvent()
        let id = e.objectID

        viewContext.delete(e)
        try viewContext.save()

        let exp = expectation(description: "invalid id treated as deleted")
        retryLimit(context: viewContext, for: id) { deleted in
            XCTAssertTrue(deleted)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_8: RequestManager.responseProcessing maps HTTP status codes to event types correctly
    func test_8_responseProcessing_maps_status_codes_to_event_types_and_payload() {
        let mgr = RequestManager()
        let url = URL(string: "https://example.com")!
        func http(_ code: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: code, httpVersion: "HTTP/1.1", headerFields: [:])!
        }

        let body = """
        {"result":"ok","detail":"unit"}
        """.data(using: .utf8)

        let ok = mgr.responseProcessing(response: http(200), data: body, requestName: "mobileEvent", name: "open")
        let srvErr = mgr.responseProcessing(response: http(503), data: body, requestName: "mobileEvent", name: "open")
        let cliErr = mgr.responseProcessing(response: http(404), data: body, requestName: "mobileEvent", name: "open")

        XCTAssertTrue(type(of: ok) == Event.self)
        XCTAssertFalse(type(of: ok) == ErrorEvent.self)
        XCTAssertTrue(type(of: srvErr) == RetryEvent.self)
        XCTAssertTrue(type(of: cliErr) == ErrorEvent.self)
        XCTAssertFalse(type(of: cliErr) == RetryEvent.self)
    }
}

