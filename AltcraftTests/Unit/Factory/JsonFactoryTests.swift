//
//  JsonFactoryAndRequestFactoryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * JsonFactoryAndRequestFactoryTests
 *
 * Positive scenarios:
 *  - test_1: subscribe → full JSON and request.
 *  - test_2: subscribe → minimal JSON defaults and request.
 *  - test_3: update → JSON nulls and request.
 *  - test_4: unSuspend → JSON and request.
 *  - test_5: pushEvent → JSON and request.
 *  - test_6: profile → GET request.
 */
final class JsonFactoryAndRequestFactoryTests: XCTestCase {

    private let keys = Constants.JSONKeys.self
    private let httpH = Constants.HTTPHeader.self
    private let httpM = Constants.HTTPMethod.self
    private let q = Constants.QueryItem.self

    private let baseURL = "https://example.com/api"
    private let auth = "Bearer abc"
    private let reqId = "req-123"

    private func decode(_ data: Data?,
                        file: StaticString = #file, line: UInt = #line) throws -> Any {
        XCTAssertNotNil(data, "Expected non-nil data", file: file, line: line)
        return try JSONSerialization.jsonObject(with: data!, options: [.fragmentsAllowed])
    }

    private func asDict(_ any: Any,
                        file: StaticString = #file, line: UInt = #line) -> [String: Any] {
        guard let d = any as? [String: Any] else {
            XCTFail("Expected top-level object", file: file, line: line)
            return [:]
        }
        return d
    }

    private func asArrayOfDict(_ any: Any,
                               file: StaticString = #file, line: UInt = #line) -> [[String: Any]] {
        guard let a = any as? [[String: Any]] else {
            XCTFail("Expected array of dicts", file: file, line: line)
            return []
        }
        return a
    }

    private func queryMap(from url: URL?) -> [String: String] {
        guard let u = url, let comps = URLComponents(url: u, resolvingAgainstBaseURL: false) else { return [:] }
        var out: [String: String] = [:]
        (comps.queryItems ?? []).forEach { out[$0.name] = $0.value ?? "" }
        return out
    }

    /// test_1: subscribe full JSON and request
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

        let body = createSubscribeJSONBody(data: data)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 1_727_000_000)
        XCTAssertEqual(root[keys.subscriptionId] as? String, "devtok-123")
        XCTAssertEqual(root[keys.replace] as? Bool, true)
        XCTAssertEqual(root[keys.skipTriggers] as? Bool, false)

        let pf = root[keys.profileFields] as? [String: Any]
        XCTAssertEqual(pf?["age"] as? Int, 30)
        XCTAssertEqual(pf?["city"] as? String, "AMS")

        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "devtok-123")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-apns")
        XCTAssertEqual(sub?[keys.status] as? String, "active")
        let fields = sub?[keys.fields] as? [String: Any]
        XCTAssertEqual(fields?["utm"] as? String, "spring-2025")

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
        XCTAssertNil(qm[q.subscriptionId])
    }

    /// test_2: subscribe minimal JSON defaults and request
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
            customFields: [:],
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

    /// test_3: update JSON nulls and request
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

        let d1 = asDict(try decode(createUpdateJSONBody(data: full)))
        XCTAssertEqual(d1[keys.oldToken] as? String, "oldT")
        XCTAssertEqual(d1[keys.oldProvider] as? String, "ios-apns")
        XCTAssertEqual(d1[keys.newToken] as? String, "newT")
        XCTAssertEqual(d1[keys.newProvider] as? String, "ios-firebase")

        let d2 = asDict(try decode(createUpdateJSONBody(data: partial)))
        XCTAssertTrue(d2[keys.oldToken] is NSNull)
        XCTAssertTrue(d2[keys.oldProvider] is NSNull)
        XCTAssertEqual(d2[keys.newToken] as? String, "T")
        XCTAssertEqual(d2[keys.newProvider] as? String, "ios-firebase")

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
        XCTAssertNil(m2[q.subscriptionId])
    }

    /// test_4: unSuspend JSON and request
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

    /// test_5: pushEvent JSON and request
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

    /// test_6: profile GET request
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
