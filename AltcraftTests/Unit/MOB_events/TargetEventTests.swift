//
//  TargetEventTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
* TargetEventTests
*
* Positive scenarios:
* - test_1: PartsFactory.createTargetEventParts → includes required text fields and optional JSON/text parts when present.
* - test_2: retryLimit → increments retryCount until max, then deletes entity.
* - test_3: clearOldTargets → deletes oldest events when threshold is exceeded.
* - test_5: createTargetEventRequest → builds valid POST multipart request with auth header.
* - test_6: getAllTargetsByTag → filters by userTag and returns events ordered by time.
* - test_7: retryLimit with invalid objectID → returns true when objectID is invalid.
* - test_8: RequestManager.responseProcessing → maps status codes to appropriate event types.
*
*/
final class TargetEventTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override class var sdkManagerContainer: NSPersistentContainer? {
        targetDatabase.persistentContainer
    }

    private func storeConfig(apiUrl: String, rToken: String) async {
        let context = CoreDataManager.shared.getContext()
        context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: Constants.EntityNames.configurationEntity
            )
            request.includesPropertyValues = false

            if let stale = try? context.fetch(request) as? [NSManagedObject] {
                stale.forEach { context.delete($0) }
            }

            let entity = NSEntityDescription.insertNewObject(
                forEntityName: Constants.EntityNames.configurationEntity,
                into: context
            )
            entity.setValue(apiUrl, forKey: "url")
            entity.setValue(rToken, forKey: "rToken")
            try? context.save()
        }
        await ConfigManager.shared.clearCache()
    }

    private func makeTargetEntity() throws -> TargetEntity {
        guard let entity = NSEntityDescription.entity(
            forEntityName: TargetConstants.EntityNames.targetEventEntity,
            in: viewContext
        ) else {
            XCTFail("Failed to resolve NSEntityDescription for TargetEntity")
            throw NSError(
                domain: "TargetEventTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve NSEntityDescription for TargetEntity"]
            )
        }

        return TargetEntity(entity: entity, insertInto: viewContext)
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
    ) throws -> TargetEntity {
        var result: TargetEntity?
        var thrownError: Error?

        viewContext.performAndWait {
            do {
                let event = try makeTargetEntity()
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

        return try XCTUnwrap(result, "makeEvent failed to produce entity")
    }

    /// test_1: PartsFactory.createTargetEventParts includes required text fields and optional JSON/text parts
    func test_1_parts_factory_includes_required_and_optional_fields() throws {
        let event = try makeEvent(tz: 90)
        let parts = PartsFactory.createTargetEventParts(from: event)

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

        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.TIME_ZONE, value: "90"))
        XCTAssertTrue(parts.contains(where: { $0.name == TargetConstants.TargetEvents.TIME_MOB }))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.ALTCRAFT_CLIENT_ID, value: "client-123"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.MOB_EVENT_NAME, value: "open"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.MATCHING_TYPE, value: "push_sub"))

        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_CAMPAIGN, value: "camp"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_CONTENT, value: "cont"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_KEYWORD, value: "kw"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_MEDIUM, value: "med"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_SOURCE, value: "src"))
        XCTAssertTrue(hasText(name: TargetConstants.TargetEvents.UTM_TEMP, value: "tmp"))

        XCTAssertTrue(hasJSON(name: TargetConstants.TargetEvents.PAYLOAD))
        XCTAssertTrue(hasJSON(name: TargetConstants.TargetEvents.MATCHING_MOB))
        XCTAssertTrue(hasJSON(name: TargetConstants.TargetEvents.PROFILE_FIELDS_MOB))
        XCTAssertTrue(parts.contains(where: { $0.name == TargetConstants.TargetEvents.SMID_MOB }))
    }

    /// test_2: retryLimit increments retryCount until max and then deletes entity
    func test_2_retryLimit_increments_and_deletes_on_max() async throws {
        let event = try makeEvent()
        let objectID = event.objectID

        let firstResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertFalse(firstResult)

        let firstFetch = try viewContext.existingObject(with: objectID) as? TargetEntity
        XCTAssertEqual(firstFetch?.retryCount, 1)

        let secondResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertFalse(secondResult)

        let secondFetch = try viewContext.existingObject(with: objectID) as? TargetEntity
        XCTAssertEqual(secondFetch?.retryCount, 2)

        let thirdResult = await retryLimit(context: viewContext, objectID: objectID)
        XCTAssertTrue(thirdResult)

        let request = NSFetchRequest<TargetEntity>(
            entityName: TargetConstants.EntityNames.targetEventEntity
        )
        let all = try viewContext.fetch(request)
        XCTAssertTrue(all.isEmpty)
    }

    /// test_3: clearOldTargets keeps threshold count logic and deletes oldest records
    func test_3_clearOldTargets_keeps_threshold_and_deletes_oldest() async throws {
        for index in 0..<10 {
            let time = Int64(1_700_000_000_000 + (index * 1000))
            _ = try makeEvent(time: time, name: "e\(index)")
        }

        let beforeRequest: NSFetchRequest<TargetEntity> = TargetEntity.fetchRequest()
        let beforeCleanup = try viewContext.fetch(beforeRequest)
        let beforeCleanupCount = beforeCleanup.count

        await TargetDAO.clearOldTargets(
            context: viewContext,
            threshold: 6,
            purgeCount: 3
        )

        let request: NSFetchRequest<TargetEntity> = TargetEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]

        let left = try viewContext.fetch(request)
        let expectedCount = beforeCleanupCount > 6 ? beforeCleanupCount - 3 : beforeCleanupCount
        XCTAssertEqual(left.count, expectedCount)

        let names = Set(left.compactMap { $0.eventName })
        XCTAssertFalse(names.contains("e0"))
        XCTAssertFalse(names.contains("e1"))
        XCTAssertFalse(names.contains("e2"))
    }

    /// test_5: createTargetEventRequest builds valid POST multipart request with Authorization header
    func test_5_create_mobile_event_request_builds_valid_multipart_request() async throws {
        await storeConfig(apiUrl: "https://api.altcraft.test", rToken: "rt")

        let data = RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: "RID-\(UUID().uuidString)",
            sid: "SID-9",
            name: "open",
            parts: [
                Part(
                    name: TargetConstants.TargetEvents.MOB_EVENT_NAME,
                    data: Data("open".utf8),
                    mime: "text/plain; charset=utf-8",
                    filename: nil
                )
            ]
        )

        let request = await mobileEventRequest(data: data)

        XCTAssertNotNil(request)
        XCTAssertEqual(request?.httpMethod, "POST")
        XCTAssertEqual(
            request?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization),
            "Bearer rtoken@rt"
        )

        let contentType = request?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        XCTAssertNotNil(request?.httpBody)

        let requestURL = try XCTUnwrap(request?.url)
        let components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        let names = Set((components?.queryItems ?? []).map { $0.name })
        XCTAssertTrue(names.isSuperset(of: ["i", "tr", "t", "v"]))
    }

    /// test_6: getAllTargetsByTag filters by userTag and orders by time
    func test_6_get_all_mobile_events_by_tag_filters_by_user_tag_and_orders_by_time() async throws {
        func add(_ tag: String, _ time: Int64, _ name: String) throws {
            let event = try makeTargetEntity()
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

        let ids = try await TargetDAO.getAllTargetsByTag(context: viewContext, userTag: "A")
        XCTAssertEqual(ids.count, 3)

        let context = viewContext
        var names: [String] = []

        context.performAndWait {
            for objectID in ids {
                if let object = try? context.existingObject(with: objectID) as? TargetEntity {
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

    /// test_8: ResponseProcessor.processResponse maps HTTP status codes to event types correctly
    func test_8_response_processing_maps_status_codes_to_event_types_and_payload() throws {
        let requestData = RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: "RID",
            sid: "SID",
            name: "open",
            parts: [],
        )

        func response(_ code: Int) throws -> HTTPURLResponse {
            let url = try XCTUnwrap(URL(string: "https://example.com"))
            return try XCTUnwrap(
                HTTPURLResponse(
                    url: url,
                    statusCode: code,
                    httpVersion: "HTTP/1.1",
                    headerFields: [:]
                )
            )
        }

        let body = """
        {"result":"ok","detail":"unit"}
        """.data(using: .utf8)

        let okResult = ResponseProcessor.processResponse(
            request: requestData,
            response: try response(200),
            data: body
        )

        let serverErrorResult = ResponseProcessor.processResponse(
            request: requestData,
            response: try response(503),
            data: body
        )

        let clientErrorResult = ResponseProcessor.processResponse(
            request: requestData,
            response: try response(404),
            data: body
        )

        XCTAssertTrue(type(of: okResult.event) == Event.self)
        XCTAssertFalse(type(of: okResult.event) == ErrorEvent.self)
        XCTAssertTrue(type(of: serverErrorResult.event) == RetryEvent.self)
        XCTAssertTrue(type(of: clientErrorResult.event) == ErrorEvent.self)
        XCTAssertFalse(type(of: clientErrorResult.event) == RetryEvent.self)
    }

    // MARK: - Init waiting

    /// Resets the shared init barrier to a fresh (incomplete) gate.
    private func resetBarrierToFreshGate() async -> InitGate {
        let current = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(current)
        await waitShort(0.01)

        var gate = await InitBarrier.shared.reserve()
        var attempts = 0

        while await gate.completed(), attempts < 5 {
            await InitBarrier.shared.complete(gate)
            await waitShort(0.01)
            gate = await InitBarrier.shared.reserve()
            attempts += 1
        }

        return gate
    }

    private func waitShort(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    private func fetchTargetCount() throws -> Int {
        let context = targetDatabase.getContext()
        var count = 0

        context.performAndWait {
            let request = NSFetchRequest<TargetEntity>(
                entityName: TargetConstants.EntityNames.targetEventEntity
            )
            count = (try? context.count(for: request)) ?? 0
        }

        return count
    }

    /// test_9: sendTargetEvent waits for SDK initialization before processing
    ///
    /// An event submitted before `initialization` completes must not be
    /// dropped: the process waits on the init barrier and stores the event
    /// once the configuration is installed (Android parity,
    /// `submitSdkCommand` with `initAwait = true`).
    func test_9_sendTargetEvent_waitsForInit_thenProcesses() async throws {
        // Configuration is present, but initialization has not completed.
        await storeConfig(apiUrl: "://invalid", rToken: "rt-init-test")

        let gate = await resetBarrierToFreshGate()

        let baseline = try fetchTargetCount()
        XCTAssertEqual(baseline, 0)

        async let run: Void = TargetEventProcess.shared.sendTargetEvent(
            sid: "pixel-init",
            eventName: "init_wait_event"
        )

        // While initialization is incomplete the event must not be processed.
        await waitShort(0.2)
        XCTAssertEqual(try fetchTargetCount(), baseline)

        // Completing initialization releases the waiting event.
        await InitBarrier.shared.complete(gate)
        _ = await run

        // The submitted job returns as soon as it is enqueued, so poll for
        // the stored event instead of asserting immediately.
        var processed = baseline
        for _ in 0..<60 {
            processed = try fetchTargetCount()
            if processed == baseline + 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(
            processed,
            baseline + 1,
            "event must be stored after initialization completes"
        )
    }
}
