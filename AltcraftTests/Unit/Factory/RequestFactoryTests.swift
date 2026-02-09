//
//  RequestFactoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * RequestFactoryTests
 *
 * Positive scenarios:
 *  - test_1: Build URL components includes only non-nil and encodes values.
 *  - test_2: Build post request sets method headers and body.
 *  - test_3: Build get request sets method and headers.
 *  - test_4: Create subscribe request success builds post with query and headers.
 *  - test_5: Create subscribe request invalid URL emits error and returns nil.
 *  - test_6: Create update request adds old token as subscription ID and uses new provider.
 *  - test_7: Create push event request uses requestId and matching mode param.
 *  - test_8: Create profile request builds GET with provider token matching mode.
 *  - test_9: Create un-suspend request builds POST with provider token matching mode.
 *  - test_10: Subscribe request end to end non-nil body and request.
 *  - test_11: Update request end to end non-nil body and request.
 *  - test_12: Push event request end to end non-nil body and request.
 *  - test_13: Un-suspend request end to end non-nil body and request.
 *  - test_14: Build mobile event URL appends query items and validates scheme host.
 *  - test_15: Build mobile event URL invalid base returns nil.
 *  - test_16: Create mobile event request builds multipart with headers boundary and URL.
 *  - test_17: Status request invalid mode returns nil quickly.
 *  - test_18: Status request no profile data emits error and returns nil.
 */
final class RequestFactoryTests: IsolatedTestCase {

    private final class EventSpy {
        private(set) var events: [Event] = []
        func start() { SDKEvents.shared.subscribe { [weak self] in self?.events.append($0) } }
        func stop()  { SDKEvents.shared.unsubscribe() }
    }

    private func components(from url: URL) -> URLComponents {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            XCTFail("Failed to resolve URLComponents")
            return URLComponents()
        }
        return c
    }

    private func queryDict(_ comps: URLComponents) -> [String: String] {
        var dict: [String: String] = [:]
        for qi in comps.queryItems ?? [] { dict[qi.name] = qi.value ?? "" }
        return dict
    }

    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") { return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) }
        if raw.hasSuffix("()") { return String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines) }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// test_1: Build URL components includes only non-nil and encodes values
    func test_1_buildURLComponents_includesOnlyNonNil_andEncodesValues() {
        let base = "https://api.altcraft.test/v1/sub"
        let provider = "ios-apns"
        let mode = "match_current_context"
        let sync = true
        let subId = "abc:123+/="

        let comps = buildURLComponents(
            url: base,
            provider: provider,
            matchingMode: mode,
            sync: sync,
            subscriptionId: subId
        )

        XCTAssertNotNil(comps)
        XCTAssertEqual(comps?.scheme, "https")
        XCTAssertEqual(comps?.host, "api.altcraft.test")
        let dict = queryDict(comps!)
        XCTAssertEqual(dict[Constants.QueryItem.provider], provider)
        XCTAssertEqual(dict[Constants.QueryItem.matchingMode], mode)
        XCTAssertEqual(dict[Constants.QueryItem.sync], String(sync))
        XCTAssertEqual(dict[Constants.QueryItem.subscriptionId], subId)
    }

    /// test_2: Build post request sets method headers and body
    func test_2_buildPostRequest_setsMethodHeadersAndBody() {
        let url = URL(string: "https://example.com/p")!
        let body = Data([1, 2, 3])
        let auth = "Bearer abc"
        let rid = "req-42"

        let req = buildPostRequest(url: url, body: body, authHeader: auth, requestId: rid)

        XCTAssertEqual(req.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req.url, url)
        XCTAssertEqual(req.httpBody, body)
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.contentType), "application/json")
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), auth)
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), rid)
    }

    /// test_3: Build get request sets method and headers
    func test_3_buildGetRequest_setsMethodAndHeaders() {
        let url = URL(string: "https://example.com/g")!
        let auth = "Bearer zzz"
        let rid = "req-77"

        let req = buildGetRequest(url: url, authHeader: auth, requestId: rid)

        XCTAssertEqual(req.httpMethod, Constants.HTTPMethod.get)
        XCTAssertNil(req.httpBody)
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.contentType), "application/json")
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), auth)
        XCTAssertEqual(req.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), rid)
    }

    /// test_4: Create subscribe request success builds post with query and headers
    func test_4_createSubscribeRequest_success_buildsPostWithQueryAndHeaders() {
        let data = SubscribeRequestData(
            url: "https://api.altcraft.test/subscribe",
            requestId: "RID-1",
            time: 1234567890,
            rToken: "rt",
            authHeader: "Bearer AAA",
            matchingMode: "match_current_context",
            provider: "ios-apns",
            deviceToken: "dev-123",
            status: "active",
            sync: true,
            profileFields: ["age": 30],
            customFields: ["utm": "spring"],
            cats: [CategoryData(name: "news", active: true)],
            replace: true,
            skipTriggers: false
        )
        let body = createSubscribeJSONBody(data: data)!
        let req = createSubscribeRequest(data: data, requestBody: body)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer AAA")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], "match_current_context")
        XCTAssertEqual(q[Constants.QueryItem.sync], "true")
        XCTAssertNil(q[Constants.QueryItem.subscriptionId])
    }

    /// test_5: Create subscribe request invalid URL emits error and returns nil
    func test_5_createSubscribeRequest_invalidURL_emitsError_andReturnsNil() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }
        let data = SubscribeRequestData(
            url: "://bad url",
            requestId: "RID-ERR",
            time: 1,
            rToken: nil,
            authHeader: "Bearer Z",
            matchingMode: "m",
            provider: "ios-apns",
            deviceToken: "dev",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        let body = createSubscribeJSONBody(data: data)!
        let req = createSubscribeRequest(data: data, requestBody: body)
        XCTAssertNil(req)
        let hasCreateError = spy.events.contains { ($0 is ErrorEvent) && normalizeFunctionName($0.function) == "createSubscribeRequest" }
        XCTAssertTrue(hasCreateError)
    }

    /// test_6: Create update request adds old token as subscription ID and uses new provider
    func test_6_createUpdateRequest_addsOldToken_asSubscriptionId_andUsesNewProvider() {
        let data = UpdateRequestData(
            url: "https://api.altcraft.test/update",
            requestId: "RID-U",
            authHeader: "Bearer U",
            oldToken: "OLD",
            newToken: "NEW",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )
        let dummyBody = Data([9,9,9])
        let req = createUpdateRequest(data: data, requestBody: dummyBody)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer U")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-U")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-firebase")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "OLD")
        XCTAssertEqual(q[Constants.QueryItem.sync], "true")
        XCTAssertNil(q[Constants.QueryItem.matchingMode])
    }

    /// test_7: Create push event request uses requestId and matching mode param
    func test_7_createPushEventRequest_usesRequestId_andMatchingModeParam() {
        let data = PushEventRequestData(
            url: "https://api.altcraft.test/event",
            requestId: "REQ-EV-1",
            time: 111,
            type: Constants.PushEvents.delivery,
            uid: "EV-1",
            authHeader: "Bearer E",
            matchingMode: "match_current_context"
        )
        let body = createPushEventJSONBody(data: data)!
        let req = createPushEventRequest(data: data, requestBody: body)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer E")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "REQ-EV-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], "match_current_context")
        XCTAssertNil(q[Constants.QueryItem.provider])
        XCTAssertNil(q[Constants.QueryItem.subscriptionId])
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_8: Create profile request builds GET with provider token matching mode
    func test_8_createProfileRequest_buildsGET_withProviderTokenMatchingMode() {
        let data = ProfileRequestData(
            url: "https://api.altcraft.test/profile",
            requestId: "RID-PR-1",
            authHeader: "Bearer P",
            matchingMode: "latest_subscription",
            provider: "ios-apns",
            token: "TOK"
        )
        let req = createProfileRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer P")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-PR-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], "latest_subscription")
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "TOK")
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_9: Create un-suspend request builds POST with provider token matching mode
    func test_9_createUnSuspendRequest_buildsPOST_withProviderTokenMatchingMode() {
        let data = UnSuspendRequestData(
            url: "https://api.altcraft.test/uns",
            requestId: "RID-UN-1",
            provider: "ios-apns",
            token: "TTT",
            authHeader: "Bearer U",
            matchingMode: "latest_for_provider"
        )
        let body = createUnSuspendJSONBody(data: data)!
        let req = createUnSuspendRequest(data: data, requestBody: body)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer U")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-UN-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], "latest_for_provider")
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "TTT")
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_10: Subscribe request end to end non-nil body and request
    func test_10_subscribeRequest_endToEnd_nonNilBodyAndRequest() {
        let data = SubscribeRequestData(
            url: "https://api.altcraft.test/subscribe",
            requestId: "RID-10",
            time: 2222,
            rToken: nil,
            authHeader: "Bearer S10",
            matchingMode: "m",
            provider: "ios-firebase",
            deviceToken: "DEV10",
            status: "active",
            sync: false,
            profileFields: nil,
            customFields: ["k":"v"],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        let req = subscribeRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
    }

    /// test_11: Update request end to end non-nil body and request
    func test_11_updateRequest_endToEnd_nonNilBodyAndRequest() {
        let data = UpdateRequestData(
            url: "https://api.altcraft.test/update",
            requestId: "RID-11",
            authHeader: "Bearer U11",
            oldToken: "OLD11",
            newToken: "NEW11",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )
        let req = updateRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
    }

    /// test_12: Push event request end to end non-nil body and request
    func test_12_pushEventRequest_endToEnd_nonNilBodyAndRequest() {
        let data = PushEventRequestData(
            url: "https://api.altcraft.test/event",
            requestId: "RID-12",
            time: 3333,
            type: Constants.PushEvents.open,
            uid: "RID-12-UID",
            authHeader: "Bearer E12",
            matchingMode: "m"
        )
        XCTAssertTrue(data.isValid())
        let req = pushEventRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-12")
    }

    /// test_13: Un-suspend request end to end non-nil body and request
    func test_13_unSuspendRequest_endToEnd_nonNilBodyAndRequest() {
        let data = UnSuspendRequestData(
            url: "https://api.altcraft.test/uns",
            requestId: "RID-13",
            provider: "ios-firebase",
            token: "TOK-13",
            authHeader: "Bearer US13",
            matchingMode: "latest_for_provider"
        )
        let req = unSuspendRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-13")
    }

    /// test_14: Build mobile event URL appends query items and validates scheme host
    func test_14_buildMobileEventURL_appendsQueryItems_andValidatesSchemeHost() {
        let base = "https://px.altcraft.test/pixel"
        let url = buildMobileEventURL(baseURLString: base, sid: "SID1", tracker: "px", type: "open", version: "2")
        XCTAssertNotNil(url)
        let comps = components(from: url!)
        let q = queryDict(comps)
        XCTAssertEqual(comps.scheme, "https")
        XCTAssertEqual(comps.host, "px.altcraft.test")
        XCTAssertEqual(q["i"], "SID1")
        XCTAssertEqual(q["tr"], "px")
        XCTAssertEqual(q["t"], "open")
        XCTAssertEqual(q["v"], "2")
    }

    /// test_15: Build mobile event URL invalid base returns nil
    func test_15_buildMobileEventURL_invalidBase_returnsNil() {
        XCTAssertNil(buildMobileEventURL(baseURLString: ":// broken", sid: "S", tracker: "px", type: "open", version: "2"))
        XCTAssertNil(buildMobileEventURL(baseURLString: "file://local", sid: "S", tracker: "px", type: "open", version: "2"))
        XCTAssertNil(buildMobileEventURL(baseURLString: "https://", sid: "S", tracker: "px", type: "open", version: "2"))
    }

    /// test_16: Create mobile event request builds multipart with headers boundary and URL
    func test_16_createMobileEventRequest_buildsMultipart_withHeadersBoundaryAndURL() {
        let parts: [Part] = [
            Part(name: "meta", data: Data(#"{"k":"v"}"#.utf8), mime: "application/json", filename: nil),
            Part(name: "file", data: Data("hello".utf8), mime: "text/plain", filename: "a.txt"),
        ]
        let data = MobileEventRequestData(
            url: "https://px.altcraft.test/pixel",
            requestId: "RID-M-1",
            sid: "SID-99",
            eventName: "test",
            parts: parts,
            authHeader: "Bearer M"
        )
        let spy = EventSpy(); spy.start(); defer { spy.stop() }
        let req = createMobileEventRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer M")

        let ctype = req?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(ctype.hasPrefix("multipart/form-data; boundary="))

        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-M-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q["i"], "SID-99")
        XCTAssertEqual(q["tr"], "px")
        XCTAssertEqual(q["t"], "open")
        XCTAssertEqual(q["v"], "2")

        let bodyStr = String(data: req!.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyStr.contains("Content-Disposition: form-data; name=\"meta\""))
        XCTAssertTrue(bodyStr.contains("Content-Type: application/json"))
        XCTAssertTrue(bodyStr.contains("Content-Disposition: form-data; name=\"file\"; filename=\"a.txt\""))
        XCTAssertTrue(bodyStr.contains("Content-Type: text/plain"))
        XCTAssertTrue((req?.value(forHTTPHeaderField: "Content-Length")).flatMap(Int.init) ?? 0 > 0)
        XCTAssertFalse(spy.events.contains { $0 is ErrorEvent })
    }

    /// test_17: Status request invalid mode returns nil quickly
    func test_17_statusRequest_invalidMode_returnsNil_quickly() {
        let exp = expectation(description: "status invalid mode")
        statusRequest(mode: "___bad___", provider: nil) { req in
            XCTAssertNil(req)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// test_18: Status request no profile data emits error and returns nil
    func test_18_statusRequest_noProfileData_emitsError_andReturnsNil() {
        let spy = EventSpy(); spy.start(); defer { spy.stop() }
        let exp = expectation(description: "status no data")
        statusRequest(mode: Constants.StatusMode.matchCurrentContext, provider: nil) { req in
            XCTAssertNil(req)
            let hasError = spy.events.contains { ($0 is ErrorEvent) && (self.normalizeFunctionName($0.function) == "statusRequest") }
            XCTAssertTrue(hasError)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}
