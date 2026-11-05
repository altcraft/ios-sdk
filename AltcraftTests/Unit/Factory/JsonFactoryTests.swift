//
//  JsonFactoryTests.swift
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
 * JsonFactoryAndRequestFactoryTests
 *
 * Positive scenarios:
 *  - test_1: subscribe → full JSON and request.
 *  - test_2: subscribe → minimal JSON defaults and request.
 *  - test_3: update → JSON nulls and request.
 *  - test_4: unSuspend → JSON and request.
 *  - test_5: pushEvent → JSON and request.
 *  - test_6: profile → GET request.
 *  - test_7: profileUpdate → JSON null/defaults.
 */
final class JsonFactoryTests: IsolatedTestCase {

    private let keys = PushConstants.JSONKeys.self
    private let httpH = Constants.HTTPHeader.self
    private let httpM = Constants.HTTPMethod.self
    private let q = Constants.QueryItem.self

    private let reqId = "req-123"

    /// Authorization header derived from the Core environment for the test rToken.
    private let expectedAuthHeader = "Bearer rtoken@rt"
    private let expectedMatching = Constants.AuthKeys.rTokenMatching

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

    /// Seeds the SDK CoreData configuration used by `CoreRequestBuilder`.
    @discardableResult
    private func storeConfig(
        apiUrl: String = "https://example.com",
        rToken: String? = "rt"
    ) async -> Bool {
        let ctx = CoreDataManager.shared.persistentContainer.newBackgroundContext()

        return await withCheckedContinuation { continuation in
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
    }

    /// test_1: subscribe → full JSON and request.
    func test_1_subscribe_full_json_and_request() async throws {
        await storeConfig()

        let cats: [CategoryData] = [
            CategoryData(name: "news",  title: "News",  steady: true,  active: true),
            CategoryData(name: "promo", title: "Promo", steady: false, active: false)
        ]
        let profile: [String: Any] = ["age": 30, "city": "AMS"]
        let custom:  [String: Any] = ["utm": "spring-2025"]

        let data = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: reqId,
            time: 1_727_000_000,
            provider: "ios-apns",
            deviceToken: "devtok-123",
            status: "active",
            sync: true,
            profileFields: profile,
            fields: custom,
            cats: cats,
            replace: true,
            skipTriggers: false
        )

        let body = createPushSubscribeJSONBody(data: data)
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

        let req = await pushSubscribeRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.contentType), "application/json")
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), reqId)

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
        XCTAssertEqual(qm[q.sync], "1")
        XCTAssertNil(qm[q.subscriptionId])
    }

    /// test_2: subscribe → minimal JSON defaults and request.
    func test_2_subscribe_minimal_json_defaults_and_request() async throws {
        await storeConfig()

        let data = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: reqId,
            time: 123,
            provider: "ios-firebase",
            deviceToken: "tok",
            status: "active",
            sync: false,
            profileFields: nil,
            fields: [:],
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        let body = createPushSubscribeJSONBody(data: data)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 123)
        XCTAssertEqual(root[keys.subscriptionId] as? String, "tok")
        XCTAssertEqual(root[keys.replace] as? Bool, false)
        XCTAssertEqual(root[keys.skipTriggers] as? Bool, false)
        XCTAssertTrue(root[keys.profileFields] is NSNull)

        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "tok")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-firebase")
        XCTAssertEqual(sub?[keys.status] as? String, "active")

        let fieldsAny = sub?[keys.fields]
        if let fieldsDict = fieldsAny as? [String: Any] {
            XCTAssertTrue(fieldsDict.isEmpty)
        } else {
            XCTFail("Expected fields dict to exist")
        }

        if let catsArr = sub?[keys.cats] as? [Any] {
            XCTAssertEqual(catsArr.count, 0)
        } else {
            XCTFail("Expected cats array to exist")
        }

        let req = await pushSubscribeRequest(data: data)
        XCTAssertNotNil(req)
        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-firebase")
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
        XCTAssertEqual(qm[q.sync], "0")
    }

    /// test_3: update → JSON nulls and request.
    func test_3_update_json_nulls_and_request() async throws {
        await storeConfig()

        let full = RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: reqId,
            oldToken: "oldT",
            newToken: "newT",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )
        let partial = RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: reqId,
            oldToken: nil,
            newToken: "T",
            oldProvider: nil,
            newProvider: "ios-firebase",
            sync: false
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

        let body1 = createUpdateJSONBody(data: full)
        XCTAssertNotNil(body1)
        let r1 = await tokenUpdateRequest(data: full)
        XCTAssertNotNil(r1)
        XCTAssertEqual(r1?.httpMethod, httpM.post)
        XCTAssertEqual(r1?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(r1?.value(forHTTPHeaderField: httpH.requestId), reqId)
        let m1 = queryMap(from: r1?.url)
        XCTAssertEqual(m1[q.provider], "ios-firebase")
        XCTAssertEqual(m1[q.subscriptionId], "oldT")
        XCTAssertEqual(m1[q.sync], "1")
        XCTAssertEqual(m1[q.matchingMode], expectedMatching)

        let body2 = createUpdateJSONBody(data: partial)
        XCTAssertNotNil(body2)
        let r2 = await tokenUpdateRequest(data: partial)
        XCTAssertNotNil(r2)
        let m2 = queryMap(from: r2?.url)
        XCTAssertEqual(m2[q.provider], "ios-firebase")
        XCTAssertNil(m2[q.subscriptionId])
        XCTAssertEqual(m2[q.sync], "0")
        XCTAssertEqual(m2[q.matchingMode], expectedMatching)
    }

    /// test_4: unSuspend → JSON and request.
    func test_4_unSuspend_json_and_request() async throws {
        await storeConfig()

        let u = RequestModel.UnSuspendRequestData(
            path: PushConstants.UrlPath.unsuspend,
            requestId: "req-un-1",
            provider: "ios-apns",
            token: "tok-1"
        )

        let body = createUnSuspendJSONBody(data: u)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.replace] as? Bool, true)

        let sub = root[keys.subscription] as? [String: Any]
        XCTAssertEqual(sub?[keys.subscriptionId] as? String, "tok-1")
        XCTAssertEqual(sub?[keys.provider] as? String, "ios-apns")

        let req = await unSuspendRequest(data: u)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "req-un-1")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
        XCTAssertEqual(qm[q.subscriptionId], "tok-1")
    }

    /// test_5: pushEvent → JSON and request.
    func test_5_pushEvent_json_and_request() async throws {
        await storeConfig()

        let p = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "req-pe-1",
            time: 111,
            type: PushConstants.PushEvents.delivery,
            uid: "smid-42"
        )

        let body = createPushEventJSONBody(data: p)
        let root = asDict(try decode(body))
        XCTAssertEqual(root[keys.time] as? Int, 111)
        XCTAssertEqual(root[keys.smid] as? String, "smid-42")

        let req = await pushEventRequest(data: p)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.post)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "req-pe-1")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
        XCTAssertNil(qm[q.provider])
        XCTAssertNil(qm[q.subscriptionId])
    }

    /// test_6: profile → GET request.
    func test_6_profile_get_request() async {
        await storeConfig()

        let pr = RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: "req-pr-9",
            provider: "ios-apns",
            token: "tok-xyz"
        )
        let req = await pushStatusRequest(data: pr)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), "req-pr-9")
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.contentType), "application/json")

        let qm = queryMap(from: req?.url)
        XCTAssertEqual(qm[q.provider], "ios-apns")
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
        XCTAssertEqual(qm[q.subscriptionId], "tok-xyz")
    }

    /// test_7: profileUpdate → JSON null/defaults.
    func test_7_profileUpdate_json_null_defaults() async throws {
        await storeConfig()
        let pk = ProfileConstants.JSONKeys.self

        let d1 = RequestModel.ProfileUpdateRequestData(
            path: ProfileConstants.UrlPath.update,
            requestId: "req-pu-1",
            profileFields: ["age": 31, "city": "AMS"],
            skipTriggers: true
        )

        let body1 = createProfileUpdateJSONBody(data: d1)
        let root1 = asDict(try decode(body1))
        let pf1 = root1[pk.profileFields] as? [String: Any]
        XCTAssertEqual(pf1?["age"] as? Int, 31)
        XCTAssertEqual(pf1?["city"] as? String, "AMS")
        XCTAssertEqual(root1[pk.skipTriggers] as? Bool, true)

        let d2 = RequestModel.ProfileUpdateRequestData(
            path: ProfileConstants.UrlPath.update,
            requestId: "req-pu-2",
            profileFields: nil,
            skipTriggers: nil
        )

        let body2 = createProfileUpdateJSONBody(data: d2)
        let root2 = asDict(try decode(body2))
        XCTAssertTrue(root2[pk.profileFields] is NSNull)
        XCTAssertTrue(root2[pk.skipTriggers] is NSNull)
    }
}
