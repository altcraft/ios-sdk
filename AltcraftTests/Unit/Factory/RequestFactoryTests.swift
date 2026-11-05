//
//  RequestFactoryTests.swift
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
 * RequestFactoryTests
 *
 * Positive scenarios:
 *  - test_1: Build URL components includes only non-nil and encodes values.
 *  - test_2: Build post request sets method headers and body.
 *  - test_3: Build get request sets method and headers.
 *  - test_4: Create subscribe request success builds post with query and headers.
 *  - test_5: Create subscribe request without auth emits error and returns nil.
 *  - test_6: Create update request adds old token as subscription ID and uses new provider.
 *  - test_7: Create push event request uses requestId and matching mode param.
 *  - test_8: Create status request builds GET with provider token matching mode.
 *  - test_9: Create un-suspend request builds POST with provider token matching mode.
 *  - test_10: Subscribe request end to end non-nil body and request.
 *  - test_11: Update request end to end non-nil body and request.
 *  - test_12: Push event request end to end non-nil body and request.
 *  - test_13: Un-suspend request end to end non-nil body and request.
 *  - test_14: Build mobile event URL appends query items and validates scheme host.
 *  - test_15: Build mobile event URL invalid base returns nil.
 *  - test_16: Create mobile event request builds multipart with headers boundary and URL.
 *  - test_17: PushStatusProcess request without Core config returns nil.
 *  - test_18: PushStatusProcess request builds GET with correct query params.
 *  - test_19: Create profile update request builds POST with headers.
 *  - test_20: Profile update request end to end non-nil body and request.
 */
final class RequestFactoryTests: IsolatedTestCase {

    /// Captures emitted SDK events.
    private final class EventSpy {
        private(set) var events: [Event] = []
        private var expectation: XCTestExpectation?
        private var fulfilled = false
        func start(expectation: XCTestExpectation? = nil) {
            self.expectation = expectation
            self.fulfilled = false
            SDKEvents.shared.subscribe { [weak self] event in
                guard let self else { return }
                self.events.append(event)
                if !self.fulfilled, let exp = self.expectation, event is ErrorEvent {
                    self.fulfilled = true
                    exp.fulfill()
                }
            }
        }
        func stop() {
            SDKEvents.shared.unsubscribe()
            expectation = nil
            fulfilled = false
        }
    }

    /// APNs provider mock.
    private final class MockAPNS: APNSInterface {
        var tokenToReturn: String?
        func getToken(completion: @escaping (String?) -> Void) { completion(tokenToReturn) }
    }

    /// Authorization header derived from the Core environment for the test rToken.
    private let expectedAuthHeader = "Bearer rtoken@rt"
    private let expectedMatching = Constants.AuthKeys.rTokenMatching

    /// Builds URLComponents from URL and fails test if not possible.
    private func components(from url: URL) -> URLComponents {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            XCTFail("Failed to resolve URLComponents")
            return URLComponents()
        }
        return c
    }

    /// Converts queryItems to dictionary for assertions.
    private func queryDict(_ comps: URLComponents) -> [String: String] {
        var dict: [String: String] = [:]
        for qi in comps.queryItems ?? [] { dict[qi.name] = qi.value ?? "" }
        return dict
    }

    /// Normalizes function name without parentheses and arguments.
    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let rawElse: String = raw else { return "" }
        var s = rawElse
        if let spaceIdx = s.firstIndex(of: " ") {
            let candidate = s[..<spaceIdx]
            if candidate.first == "[" && candidate.last == "]" {
                s = String(s[s.index(after: spaceIdx)...])
            }
        }
        if let idx = s.firstIndex(of: "(") {
            return String(s[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if s.hasSuffix("()") {
            return String(s.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Seeds the SDK CoreData configuration used by `CoreRequestBuilder`.
    ///
    /// - Parameters:
    ///   - apiUrl: Base API URL resolved by Core.
    ///   - rToken: Resource token used to derive the authorization header.
    /// - Returns: `true` when the configuration was persisted.
    @discardableResult
    private func storeConfig(
        apiUrl: String = "https://api.altcraft.test",
        rToken: String? = "rt"
    ) async -> Bool {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        let persisted: Bool = await withCheckedContinuation { continuation in
            ctx.perform {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: Constants.EntityNames.configurationEntity
                )
                req.includesPropertyValues = false

                if let objects = try? ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach { ctx.delete($0) }
                }

                let object = NSEntityDescription.insertNewObject(
                    forEntityName: Constants.EntityNames.configurationEntity,
                    into: ctx
                )
                object.setValue(apiUrl, forKey: "url")
                object.setValue(rToken, forKey: "rToken")

                try? ctx.save()
                continuation.resume(returning: true)
            }
        }
        // The config cache is process-wide: reset it so request builders
        // observe the row just written instead of a stale cached value.
        await ConfigManager.shared.clearCache()
        return persisted
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
        XCTAssertEqual(dict[Constants.QueryItem.sync], sync ? "1" : "0")
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
    func test_4_createSubscribeRequest_success_buildsPostWithQueryAndHeaders() async {
        await storeConfig()

        let data = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-1",
            time: 1234567890,
            provider: "ios-apns",
            deviceToken: "dev-123",
            status: "active",
            sync: true,
            profileFields: ["age": 30],
            fields: ["utm": "spring"],
            cats: [CategoryData(name: "news", active: true)],
            replace: true,
            skipTriggers: false
        )
        let req = await pushSubscribeRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
        XCTAssertEqual(q[Constants.QueryItem.sync], "1")
        XCTAssertNil(q[Constants.QueryItem.subscriptionId])
    }

    /// Deletes any existing configuration from the process-wide SDK store so a
    /// following assertion may rely on "no configuration" regardless of what
    /// sibling tests persisted earlier in this process. Also resets the
    /// `ConfigManager` cache, which is process-wide and would otherwise serve
    /// a stale configuration deleted here.
    private func clearConfig() async {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()
        await withCheckedContinuation { continuation in
            ctx.perform {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: Constants.EntityNames.configurationEntity
                )
                req.includesPropertyValues = false
                if let objects = try? ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach { ctx.delete($0) }
                }
                try? ctx.save()
                continuation.resume()
            }
        }
        await ConfigManager.shared.clearCache()
    }

    /// test_5: Create subscribe request without Core config/auth emits error and returns nil
    func test_5_createSubscribeRequest_withoutAuth_emitsError_andReturnsNil() async {
        await clearConfig()
        let emittedError = expectation(description: "Error event should be emitted")
        let spy = EventSpy(); spy.start(expectation: emittedError); defer { spy.stop() }

        let data = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-ERR",
            time: 1,
            provider: "ios-apns",
            deviceToken: "dev",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        let req = await pushSubscribeRequest(data: data)
        XCTAssertNil(req)

        await fulfillment(of: [emittedError], timeout: 2.0)
        XCTAssertTrue(spy.events.contains { $0 is ErrorEvent })
    }

    /// test_6: Create update request adds old token as subscription ID and uses new provider
    func test_6_createUpdateRequest_addsOldToken_asSubscriptionId_andUsesNewProvider() async {
        await storeConfig()

        let data = RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: "RID-U",
            oldToken: "OLD",
            newToken: "NEW",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )
        let req = await tokenUpdateRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-U")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-firebase")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "OLD")
        XCTAssertEqual(q[Constants.QueryItem.sync], "1")
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
    }

    /// test_7: Create push event request uses requestId and matching mode param
    func test_7_createPushEventRequest_usesRequestId_andMatchingModeParam() async {
        await storeConfig()

        let data = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "REQ-EV-1",
            time: 111,
            type: PushConstants.PushEvents.delivery,
            uid: "EV-1"
        )
        let req = await pushEventRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "REQ-EV-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
        XCTAssertNil(q[Constants.QueryItem.provider])
        XCTAssertNil(q[Constants.QueryItem.subscriptionId])
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_8: Create status request builds GET with provider token matching mode
    func test_8_createStatusRequest_buildsGET_withProviderTokenMatchingMode() async {
        await storeConfig()

        let data = RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: "RID-PR-1",
            provider: "ios-apns",
            token: "TOK"
        )
        let req = await pushStatusRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-PR-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "TOK")
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_9: Create un-suspend request builds POST with provider token matching mode
    func test_9_createUnSuspendRequest_buildsPOST_withProviderTokenMatchingMode() async {
        await storeConfig()

        let data = RequestModel.UnSuspendRequestData(
            path: PushConstants.UrlPath.unsuspend,
            requestId: "RID-UN-1",
            provider: "ios-apns",
            token: "TTT"
        )
        let req = await unSuspendRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-UN-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "TTT")
        XCTAssertNil(q[Constants.QueryItem.sync])
    }

    /// test_10: Subscribe request end to end non-nil body and request
    func test_10_subscribeRequest_endToEnd_nonNilBodyAndRequest() async {
        await storeConfig()

        let data = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-10",
            time: 2222,
            provider: "ios-firebase",
            deviceToken: "DEV10",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: ["k": "v"],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )
        let req = await pushSubscribeRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
    }

    /// test_11: Update request end to end non-nil body and request
    func test_11_updateRequest_endToEnd_nonNilBodyAndRequest() async {
        await storeConfig()

        let data = RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: "RID-11",
            oldToken: "OLD11",
            newToken: "NEW11",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )
        let req = await tokenUpdateRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
    }

    /// test_12: Push event request end to end non-nil body and request
    func test_12_pushEventRequest_endToEnd_nonNilBodyAndRequest() async {
        await storeConfig()

        let data = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-12",
            time: 3333,
            type: PushConstants.PushEvents.open,
            uid: "RID-12-UID"
        )
        XCTAssertTrue(data.isValid)
        let req = await pushEventRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-12")
    }

    /// test_13: Un-suspend request end to end non-nil body and request
    func test_13_unSuspendRequest_endToEnd_nonNilBodyAndRequest() async {
        await storeConfig()

        let data = RequestModel.UnSuspendRequestData(
            path: PushConstants.UrlPath.unsuspend,
            requestId: "RID-13",
            provider: "ios-firebase",
            token: "TOK-13"
        )
        let req = await unSuspendRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-13")
    }

    /// test_16: Create mobile event request builds multipart with headers boundary and URL
    func test_16_createTargetEventRequest_buildsMultipart_withHeadersBoundaryAndURL() async {
        await storeConfig()

        let parts: [AltcraftTarget.Part] = [
            AltcraftTarget.Part(name: "meta", data: Data(#"{"k":"v"}"#.utf8), mime: "application/json", filename: nil),
            AltcraftTarget.Part(name: "file", data: Data("hello".utf8), mime: "text/plain", filename: "a.txt"),
        ]
        let data = RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: "RID-M-1",
            sid: "SID-99",
            name: "test",
            parts: parts
        )
        let spy = EventSpy(); spy.start(); defer { spy.stop() }
        let req = await mobileEventRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)

        let ctype = req?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType) ?? ""
        XCTAssertTrue(ctype.hasPrefix("multipart/form-data; boundary="))
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-M-1")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q["i"], "SID-99")
        XCTAssertEqual(q["tr"], "px")
        XCTAssertEqual(q["t"], "open")
        XCTAssertEqual(q["v"], "2")
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)

        let bodyStr = String(data: req!.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(bodyStr.contains("Content-Disposition: form-data; name=\"meta\""))
        XCTAssertTrue(bodyStr.contains("Content-Type: application/json"))
        XCTAssertTrue(bodyStr.contains("Content-Disposition: form-data; name=\"file\"; filename=\"a.txt\""))
        XCTAssertTrue(bodyStr.contains("Content-Type: text/plain"))

        let contentLength = (req?.value(forHTTPHeaderField: "Content-Length")).flatMap(Int.init) ?? 0
        XCTAssertTrue(contentLength > 0)

        XCTAssertFalse(spy.events.contains { $0 is ErrorEvent })
    }

    /// test_17: Push status request without Core config returns nil
    func test_17_pushStatusRequest_withoutCoreConfig_returnsNil() async {
        await clearConfig()
        let data = RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: "RID-17",
            provider: "ios-apns",
            token: "TOK"
        )
        let req = await pushStatusRequest(data: data)
        XCTAssertNil(req)
    }

    /// test_18: Push status request builds GET with correct query params
    func test_18_pushStatusRequest_buildsGET_withCorrectQueryParams() async {
        await storeConfig()

        let data = RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: "RID-18",
            provider: "ios-apns",
            token: "TOK-18"
        )
        let req = await pushStatusRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-18")

        let comps = components(from: req!.url!)
        let q = queryDict(comps)
        XCTAssertEqual(q[Constants.QueryItem.matchingMode], expectedMatching)
        XCTAssertEqual(q[Constants.QueryItem.provider], "ios-apns")
        XCTAssertEqual(q[Constants.QueryItem.subscriptionId], "TOK-18")
    }
    
    /// test_19: Create profile update request builds POST with headers
    func test_19_createProfileUpdateRequest_buildsPOST_withHeaders() async {
        await storeConfig()

        let data = RequestModel.ProfileUpdateRequestData(
            path: ProfileConstants.UrlPath.update,
            requestId: "RID-PU-1",
            profileFields: ["email": "a@b.com"],
            skipTriggers: true
        )

        let req = await profileUpdateRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-PU-1")
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType), "application/json")

        let comps = components(from: req!.url!)
        XCTAssertTrue((comps.queryItems ?? []).isEmpty == false)
    }

    /// test_20: Profile update request end to end non-nil body and request
    func test_20_profileUpdateRequest_endToEnd_nonNilBodyAndRequest() async {
        await storeConfig()

        let data = RequestModel.ProfileUpdateRequestData(
            path: ProfileConstants.UrlPath.update,
            requestId: "RID-PU-2",
            profileFields: ["a": 1],
            skipTriggers: nil
        )

        let req = await profileUpdateRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, Constants.HTTPMethod.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-PU-2")
    }
}
