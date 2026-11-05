//
//  InAppStatusRequestTests.swift
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
 * InAppStatusRequestTests
 *
 * Positive scenarios:
 *  - test_1: status path constant matches the Android endpoint "/inapp/status".
 *  - test_2: inAppStatusRequest builds a GET request with the status path,
 *    subscription_id query, matching mode and standard headers.
 *  - test_3: inAppStatusRequest omits subscription_id when deviceId is nil.
 */
final class InAppStatusRequestTests: IsolatedTestCase {

    private let q = Constants.QueryItem.self
    private let iq = InAppConstants.QueryItem.self
    private let httpH = Constants.HTTPHeader.self
    private let httpM = Constants.HTTPMethod.self

    private let reqId = "req-st-1"

    /// Authorization header derived from the Core environment for the test rToken.
    private let expectedAuthHeader = "Bearer rtoken@rt"
    private let expectedMatching = Constants.AuthKeys.rTokenMatching

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

    private func queryMap(from url: URL?) -> [String: String] {
        guard let u = url,
              let comps = URLComponents(url: u, resolvingAgainstBaseURL: false)
        else { return [:] }
        var out: [String: String] = [:]
        (comps.queryItems ?? []).forEach { out[$0.name] = $0.value ?? "" }
        return out
    }

    /// test_1: status path constant matches the Android endpoint "/inapp/status".
    func test_1_statusPath_matchesAndroidEndpoint() {
        XCTAssertEqual(InAppConstants.UrlPath.status, "/inapp/status")
    }

    /// test_2: inAppStatusRequest builds a GET request with the status path,
    /// subscription_id query, matching mode and standard headers.
    func test_2_inAppStatusRequest_buildsGetWithPathQueryAndHeaders() async {
        await storeConfig()

        let data = RequestModel.InAppStatusRequestData(
            path: InAppConstants.UrlPath.status,
            requestId: reqId,
            deviceId: "device-1"
        )

        let req = await inAppStatusRequest(data: data)
        XCTAssertNotNil(req)
        XCTAssertEqual(req?.httpMethod, httpM.get)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.contentType), "application/json")
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.authorization), expectedAuthHeader)
        XCTAssertEqual(req?.value(forHTTPHeaderField: httpH.requestId), reqId)

        guard let url = req?.url,
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            XCTFail("Expected a valid request URL")
            return
        }

        XCTAssertEqual(comps.scheme, "https")
        XCTAssertEqual(comps.host, "example.com")
        XCTAssertEqual(comps.path, InAppConstants.UrlPath.status)
        XCTAssertTrue(
            url.absoluteString.contains(InAppConstants.UrlPath.status),
            "URL must point to /inapp/status"
        )

        let qm = queryMap(from: url)
        XCTAssertEqual(qm[iq.subscriptionId], "device-1")
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
    }

    /// test_3: inAppStatusRequest omits subscription_id when deviceId is nil.
    func test_3_inAppStatusRequest_omitsSubscriptionId_whenDeviceIdIsNil() async {
        await storeConfig()

        let data = RequestModel.InAppStatusRequestData(
            path: InAppConstants.UrlPath.status,
            requestId: reqId,
            deviceId: nil
        )

        let req = await inAppStatusRequest(data: data)
        XCTAssertNotNil(req)

        let qm = queryMap(from: req?.url)
        XCTAssertNil(qm[iq.subscriptionId])
        XCTAssertEqual(qm[q.matchingMode], expectedMatching)
    }
}
