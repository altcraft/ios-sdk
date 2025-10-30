//
//  JsonFactoryAndRequestFactoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * JsonFactoryAndRequestFactoryTests (iOS 13 compatible)
 *
 * Positive:
 *  - test_1_subscribe_full_json_and_request
 *  - test_2_subscribe_minimal_json_defaults_and_request
 *  - test_3_update_json_nulls_and_request
 *  - test_4_unSuspend_json_and_request
 *  - test_5_pushEvent_json_and_request
 *  - test_6_profile_get_request
 *
 * Notes:
 *  - Validates JSON payload shape + URLRequest method/headers/query/body echo.
 *  - Assumes Constants.* keys are available to tests.
 */
final class JsonFactoryAndRequestFactoryTests: XCTestCase {

    // MARK: - Constants

    private let keys = Constants.JSONKeys.self
    private let httpH = Constants.HTTPHeader.self
    private let httpM = Constants.HTTPMethod.self
    private let q = Constants.QueryItem.self

    private let baseURL = "https://example.com/api"
    private let auth = "Bearer abc"
    private let reqId = "req-123"

    // MARK: - Helpers

    /// Decode Data -> Any JSON.
    private func decode(_ data: Data?,
                        file: StaticString = #file, line: UInt = #line) throws -> Any {
        XCTAssertNotNil(data, "Expected non-nil data", file: file, line: line)
        return try JSONSerialization.jsonObject(with: data!, options: [.fragmentsAllowed])
    }

    /// Cast Any -> [String: Any].
    private func asDict(_ any: Any,
                        file: StaticString = #file, line: UInt = #line) -> [String: Any] {
        guard let d = any as? [String: Any] else {
            XCTFail("Expected top-level object", file: file, line: line)
            return [:]
        }
        return d
    }

    /// Cast Any -> [[String: Any]].
    private func asArrayOfDict(_ any: Any,
                               file: StaticString = #file, line: UInt = #line) -> [[String: Any]] {
        guard let a = any as? [[String: Any]] else {
            XCTFail("Expected array of dicts", file: file, line: line)
            return []
        }
        return a
    }

    /// Parse URL query items into a simple map.
    private func queryMap(from url: URL?) -> [String: String] {
        guard let u = url, let comps = URLComponents(url: u, resolvingAgainstBaseURL: false) else { return [:] }
        var out: [String: String] = [:]
        (comps.queryItems ?? []).forEach { out[$0.name] = $0.value ?? "" }
        return out
    }

    // MARK: - Tests

    /// Full subscribe: JSON fields + POST request headers/query/body.
    func test_1_subscribe_full_json_and_request() throws {
        let cats: [CategoryData] = [
            CategoryData(name: "news",  title: "News",  steady: true,  active: true),
            CategoryData(name: "promo", title: "Promo", steady: false, active: false)
        ]
        let profile: [String: Any] = ["age": 30, "city": "AMS"]
        let custom:  [String: Any] = ["utm": "spring-2025"]

        let data = SubscribeRequestData(
            url: baseURL,
            time: 1_727_000_000,
            rToken: nil,
            requestId: reqId,
            authHeader: auth,
            matchingMode: "latest_subscription",
            provider: "ios-apns",
            deviceToken: "devtok-123",
            status: "active",
            sync: 7,
            profileFields: profile,
            customFields: custom,
            cats: cats,
            replace: true,
            skipTriggers: false
        )

        // JSON body
        let body = createSubscribeJSONBody(data: data)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 1_727_000_000)
        XCTAssertEqual(root[keys.subscriptionId] as? String, "devtok-123")
        XCTAssertEqual(root[keys.replace] as? Bool, true)
        XCTAssertEqual(root[keys.skipTriggers] as? Bool, false)

        // profileFields
        let pf = root[keys.profileFields] as? [String: Any]
        XCTAssertEqual(pf?["age"] as? Int, 30)
        XCTAssertEqual(pf?["city"] as? String, "AMS")

        // subscription block
        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "devtok-123")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-apns")
        XCTAssertEqual(sub?[keys.status] as? String, "active")
        let fields = sub?[keys.fields] as? [String: Any]
        XCTAssertEqual(fields?["utm"] as? String, "spring-2025")

        // cats array
        let arr = asArrayOfDict(sub?[keys.cats] as Any)
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0][keys.catsName] as? String, "news")
        XCTAssertEqual(arr[0][keys.catsTitle] as? String, "News")
        XCTAssertEqual(arr[0][keys.catsSteady] as? Bool, true)
        XCTAssertEqual(arr[0][keys.catsActive] as? Bool, true)
        XCTAssertEqual(arr[1][keys.catsName] as? String, "promo")
        XCTAssertEqual(arr[1][keys.catsTitle] as? String, "Promo")
        XCTAssertEqual(arr[1][keys.catsSteady] as? Bool, false)
        XCTAssertEqual(arr[1][keys.catsActive] as? Bool, false)

        // Request
        let req = createSubscribeRequest(data: data, requestBody: body!)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.contentType), "application/json")
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), auth)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), reqId)

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], "latest_subscription")
        XCTAssertEqual(qm[q.sync], "7")
        XCTAssertNil(qm[q.subscriptionId]) // not set for subscribe
    }

    /// Minimal subscribe: defaults for replace/skipTriggers, empty cats, POST request.
    func test_2_subscribe_minimal_json_defaults_and_request() throws {
        let data = SubscribeRequestData(
            url: baseURL,
            time: 123,
            rToken: nil,
            requestId: reqId,
            authHeader: auth,
            matchingMode: "match_current_context",
            provider: "ios-firebase",
            deviceToken: "tok",
            status: "active",
            sync: 0,
            profileFields: nil,
            customFields: [:],  // non-optional in struct
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        let body = createSubscribeJSONBody(data: data)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 123)
        XCTAssertEqual(root[keys.subscriptionId] as? String, "tok")
        XCTAssertEqual(root[keys.replace] as? Bool, false)
        XCTAssertEqual(root[keys.skipTriggers] as? Bool, false)
        XCTAssertNil(root[keys.profileFields])

        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "tok")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-firebase")
        XCTAssertEqual(sub?[keys.status] as? String, "active")

        // customFields empty: accept either no key or an empty dict {}
        let fieldsAny = sub?[keys.fields]
        if let fieldsDict = fieldsAny as? [String: Any] {
            XCTAssertTrue(fieldsDict.isEmpty, "Expected empty fields dict when customFields is empty")
        } else {
            XCTAssertNil(fieldsAny)
        }

        if let catsArr = sub?[keys.cats] as? [Any] {
            XCTAssertEqual(catsArr.count, 0)
        } else {
            XCTFail("Expected cats array to exist")
        }

        let req = createSubscribeRequest(data: data, requestBody: body!)
        XCTAssertNotNil(req)
        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-firebase")
        XCTAssertEqual(qm[q.matchingMode], "match_current_context")
        XCTAssertEqual(qm[q.sync], "0")
    }

    /// Update: JSON nulls for optionals, POST request uses newProvider + oldToken in query.
    func test_3_update_json_nulls_and_request() throws {
        let full = UpdateRequestData(
            url: baseURL,
            requestId: reqId,
            authHeader: auth,
            oldToken: "oldT",
            newToken: "newT",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase"
        )
        let partial = UpdateRequestData(
            url: baseURL,
            requestId: reqId,
            authHeader: auth,
            oldToken: nil,
            newToken: "T",
            oldProvider: nil,
            newProvider: "ios-firebase"
        )

        // JSON full
        let d1 = asDict(try decode(createUpdateJSONBody(data: full)))
        XCTAssertEqual(d1[keys.oldToken] as? String, "oldT")
        XCTAssertEqual(d1[keys.oldProvider] as? String, "ios-apns")
        XCTAssertEqual(d1[keys.newToken] as? String, "newT")
        XCTAssertEqual(d1[keys.newProvider] as? String, "ios-firebase")

        // JSON partial (nils → NSNull)
        let d2 = asDict(try decode(createUpdateJSONBody(data: partial)))
        XCTAssertTrue(d2[keys.oldToken] is NSNull)
        XCTAssertTrue(d2[keys.oldProvider] is NSNull)
        XCTAssertEqual(d2[keys.newToken] as? String, "T")
        XCTAssertEqual(d2[keys.newProvider] as? String, "ios-firebase")

        // Request query = newProvider + oldToken
        let r1 = createUpdateRequest(data: full, requestBody: try! JSONSerialization.data(withJSONObject: d1))
        XCTAssertNotNil(r1)
        XCTAssertEqual(r1?.httpMethod, httpM.post)
        XCTAssertEqual(r1?.value(forHTTPHeaderField: httpH.authorization), auth)
        XCTAssertEqual(r1?.value(forHTTPHeaderField: httpH.requestId), reqId)
        let m1 = queryMap(from: r1?.url)
        XCTAssertEqual(m1[q.provider], "ios-firebase")
        XCTAssertEqual(m1[q.subscriptionId], "oldT")

        let r2 = createUpdateRequest(data: partial, requestBody: try! JSONSerialization.data(withJSONObject: d2))
        XCTAssertNotNil(r2)
        let m2 = queryMap(from: r2?.url)
        XCTAssertEqual(m2[q.provider], "ios-firebase")
        XCTAssertNil(m2[q.subscriptionId]) // oldToken nil → no query item
    }

    /// unSuspend: JSON subscription wrapper + replace=true; POST request query.
    func test_4_unSuspend_json_and_request() throws {
        let u = UnSuspendRequestData(
            url: baseURL,
            uid: "uid-1",
            provider: "ios-apns",
            token: "tok-1",
            authHeader: auth,
            matchingMode: "latest_for_provider"
        )

        let body = createUnSuspendJSONBody(data: u)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.replace] as? Bool, true)

        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "tok-1")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-apns")

        let req = createUnSuspendRequest(data: u, requestBody: body!)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), auth)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "uid-1")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], "latest_for_provider")
        XCTAssertEqual(qm[q.subscriptionId], "tok-1")
    }

    /// pushEvent: JSON (time, smid), POST request query + headers.
    func test_5_pushEvent_json_and_request() throws {
        let p = PushEventRequestData(
            url: baseURL,
            time: 111,
            type: Constants.PushEvents.delivery,
            uid: "smid-42",
            authHeader: auth,
            matchingMode: "match_current_context"
        )

        let body = createPushEventJSONBody(data: p)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 111)
        XCTAssertEqual(root[keys.smid] as? String, "smid-42")

        let req = createPushEventRequest(data: p, requestBody: body!)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), auth)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "smid-42")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.matchingMode], "match_current_context")
        XCTAssertNil(qm[q.provider])
        XCTAssertNil(qm[q.subscriptionId])
    }

    /// profile GET: query items + headers.
    func test_6_profile_get_request() {
        let pr = ProfileRequestData(
            url: baseURL,
            uid: "uid-9",
            authHeader: auth,
            matchingMode: "latest_for_provider",
            provider: "ios-apns",
            token: "tok-xyz"
        )
        let req = createProfileRequest(data: pr)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), auth)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "uid-9")
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.contentType), "application/json")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], "latest_for_provider")
        XCTAssertEqual(qm[q.subscriptionId], "tok-xyz")
    }
}

