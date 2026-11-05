//
//  RequestManagerTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
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
* RequestManagerTests
*
* Positive scenarios:
* - test_1: ResponseProcessor.processResponse success 2xx returns Event with mapped data.
* - test_2: ResponseProcessor.processResponse server error 5xx returns RetryEvent with message.
* - test_3: ResponseProcessor.processResponse client error 4xx returns ErrorEvent.
* - test_4: redirect delegate preserves critical headers.
* - test_5: ResponseProcessor.processResponse with PushSubscribeRequestData success returns Event.
* - test_6: ResponseProcessor.processResponse with non-JSON body still returns correct event type.
* - test_7: ResponseProcessor.processResponse with empty body returns correct event type.
 * - test_8: ResponseProcessor.processResponse mobile event success includes name in event data.
 * - test_9: concurrent access to the shared session yields a single URLSession instance.
 * - test_10: String.isJsonString mirrors Android SubFunction.isJsonString.
 * - test_11: processResponse with a 502 HTML body returns a retry event
 *   without a parse attempt (no decode error log path).
 *
 */
final class RequestManagerTests: IsolatedTestCase {

    private func http(_ code: Int) throws -> HTTPURLResponse {
        let url = try XCTUnwrap(URL(string: "https://example.com/api"))
        return try XCTUnwrap(
            HTTPURLResponse(
                url: url,
                statusCode: code,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )
        )
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [])
    }

    /// ResponseProcessor.processResponse success 2xx returns Event with mapped data
    func test_1_responseProcessing_success_2xx_returns_event() throws {
        let requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-1",
            time: 1000,
            type: PushConstants.PushEvents.delivery,
            uid: "U1",
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(200),
            data: try json([:])
        )

        XCTAssertEqual(result.httpCode, 200)
        XCTAssertTrue(type(of: result.event) == Event.self)
        XCTAssertFalse(result.event is ErrorEvent)
        XCTAssertEqual(result.event.event as? PushModuleEvents, .pushEventRequestSuccessful)
    }

    /// ResponseProcessor.processResponse server error 5xx returns RetryEvent with message
    func test_2_responseProcessing_server_error_5xx_returns_retry_event() throws {
        let requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-2",
            time: 1000,
            provider: "ios-apns",
            deviceToken: "DEV",
            status: Constants.SubStatus.subscribed,
            sync: true,
            profileFields: nil,
            fields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(503),
            data: try json(["error": 123, "errorText": "boom"])
        )

        XCTAssertEqual(result.httpCode, 503)
        XCTAssertTrue(result.event is RetryEvent)
        XCTAssertTrue((result.event.message ?? "").contains("503"))
    }

    /// ResponseProcessor.processResponse client error 4xx returns ErrorEvent
    func test_3_responseProcessing_client_error_4xx_returns_error_event() throws {
        let requestData = RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: "RID-3",
            oldToken: "OLD",
            newToken: "NEW",
            oldProvider: "ios-apns",
            newProvider: "ios-firebase",
            sync: true
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(409),
            data: try json(["error": 12, "errorText": "bad"])
        )

        XCTAssertEqual(result.httpCode, 409)
        XCTAssertTrue(result.event is ErrorEvent)
        XCTAssertFalse(result.event is RetryEvent)
    }

    /// redirect delegate preserves critical headers
    func test_4_redirect_delegate_preserves_critical_headers() throws {
        let manager = RequestManager.shared

        let firstURL = URL(string: "https://stub.local/redirect")!
        let secondURL = URL(string: "https://stub.local/final")!

        var originalRequest = URLRequest(url: firstURL)
        originalRequest.httpMethod = "GET"
        originalRequest.setValue("Bearer SECRET", forHTTPHeaderField: Constants.HTTPHeader.authorization)
        originalRequest.setValue("RID-REDIR", forHTTPHeaderField: Constants.HTTPHeader.requestId)
        originalRequest.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)

        let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: originalRequest)

        let redirectResponse = try XCTUnwrap(
            HTTPURLResponse(
                url: firstURL,
                statusCode: 302,
                httpVersion: "HTTP/1.1",
                headerFields: ["Location": secondURL.absoluteString]
            )
        )

        var newRequest = URLRequest(url: secondURL)
        newRequest.httpMethod = "GET"

        let expectation = expectation(description: "Delegate returns modified request")

        manager.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: redirectResponse,
            newRequest: newRequest
        ) { modifiedRequest in
            XCTAssertNotNil(modifiedRequest)
            XCTAssertEqual(
                modifiedRequest?.value(forHTTPHeaderField: Constants.HTTPHeader.authorization),
                "Bearer SECRET"
            )
            XCTAssertEqual(
                modifiedRequest?.value(forHTTPHeaderField: Constants.HTTPHeader.requestId),
                "RID-REDIR"
            )
            XCTAssertEqual(
                modifiedRequest?.value(forHTTPHeaderField: Constants.HTTPHeader.contentType),
                "application/json"
            )
            XCTAssertEqual(modifiedRequest?.url, secondURL)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    /// ResponseProcessor.processResponse with PushSubscribeRequestData success returns Event
    func test_5_responseProcessing_subscribe_success_returns_event() throws {
        let requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-5",
            time: 1000,
            provider: "ios-apns",
            deviceToken: "DEV5",
            status: Constants.SubStatus.subscribed,
            sync: true,
            profileFields: nil,
            fields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(200),
            data: try json([:])
        )

        XCTAssertEqual(result.httpCode, 200)
        XCTAssertTrue(type(of: result.event) == Event.self)
        XCTAssertEqual(result.event.event as? PushModuleEvents, .pushSubscribeRequestSuccessful)
    }

    /// ResponseProcessor.processResponse with non-JSON body still returns correct event type
    func test_6_responseProcessing_nonJson_body_still_returns_correct_event() throws {
        let requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-6",
            time: 1000,
            type: PushConstants.PushEvents.delivery,
            uid: "U6",
        )

        let nonJsonData = Data("not json".utf8)

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(200),
            data: nonJsonData
        )

        XCTAssertEqual(result.httpCode, 200)
        XCTAssertTrue(type(of: result.event) == Event.self)
    }

    /// ResponseProcessor.processResponse with empty body returns correct event type
    func test_7_responseProcessing_empty_body_returns_correct_event() throws {
        let requestData = RequestModel.PushEventRequestData(
            path: PushConstants.UrlPath.event,
            requestId: "RID-7",
            time: 1000,
            type: PushConstants.PushEvents.open,
            uid: "U7",
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(200),
            data: nil
        )

        XCTAssertEqual(result.httpCode, 200)
        XCTAssertTrue(type(of: result.event) == Event.self)
    }

    /// ResponseProcessor.processResponse mobile event success includes name in event data
    func test_8_responseProcessing_mobile_event_success_includes_name() throws {
        let requestData = RequestModel.TargetEventRequestData(
            path: TargetConstants.UrlPath.event,
            requestId: "RID-8",
            sid: "SID-8",
            name: "open app",
            parts: [],
        )

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(200),
            data: try json([:])
        )

        XCTAssertEqual(result.httpCode, 200)
        XCTAssertTrue(type(of: result.event) == Event.self)
        XCTAssertEqual(result.event.event as? TargetModuleEvents, .mobileEventRequestSuccessful)

        let ev = result.event.value
        XCTAssertEqual(ev?[Constants.MapKeys.name] as? String, "open app")
        XCTAssertNotNil(ev?[MapBuilder.httpCodeKey])
    }

    /// test_9: concurrent access to the shared session yields a single
    /// URLSession instance
    func test_9_concurrentSessionAccess_createsSingleSession() async throws {
        let manager = RequestManager.shared

        let identifiers = try await withThrowingTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    manager.test_sessionIdentifier()
                }
            }
            var ids: [ObjectIdentifier] = []
            for try await id in group {
                ids.append(id)
            }
            return ids
        }

        XCTAssertEqual(identifiers.count, 100)
        XCTAssertEqual(Set(identifiers).count, 1)
    }

    /// test_10: String.isJsonString mirrors Android SubFunction.isJsonString —
    /// non-blank bodies starting with `{` or `[` (after leading whitespace)
    /// are treated as JSON.
    func test_10_isJsonString_helper_mirrorsAndroidParity() {
        XCTAssertTrue("{\"error\":1}".isJsonString)
        XCTAssertTrue("[1,2,3]".isJsonString)
        XCTAssertTrue("  \n\t{\"error\":1}".isJsonString, "Leading whitespace must be ignored")

        XCTAssertFalse("".isJsonString, "Empty body is not JSON")
        XCTAssertFalse("   ".isJsonString, "Blank body is not JSON")
        XCTAssertFalse("<html><body>502 Bad Gateway</body></html>".isJsonString)
        XCTAssertFalse("not json".isJsonString)
    }

    /// test_11: processResponse with a 502 HTML body returns a retry event
    /// and no parsed response; the body must not be passed to the decoder
    /// (mirrors Android Response.parseResponse skipping non-JSON bodies).
    func test_11_responseProcessing_502HtmlBody_returnsRetryEventWithoutParseAttempt() throws {
        let requestData = RequestModel.PushSubscribeRequestData(
            path: PushConstants.UrlPath.subscribe,
            requestId: "RID-11",
            time: 1000,
            provider: "ios-apns",
            deviceToken: "DEV11",
            status: Constants.SubStatus.subscribed,
            sync: true,
            profileFields: nil,
            fields: nil,
            cats: nil,
            replace: nil,
            skipTriggers: nil
        )

        let htmlBody = Data("<html><body><h1>502 Bad Gateway</h1></body></html>".utf8)

        let result = ResponseProcessor.processResponse(
            request: requestData,
            response: try http(502),
            data: htmlBody
        )

        XCTAssertEqual(result.httpCode, 502)
        XCTAssertNil(result.response, "HTML body must not produce a parsed response")
        XCTAssertTrue(result.event is RetryEvent)
        XCTAssertTrue((result.event.message ?? "").contains("502"))
    }
}
