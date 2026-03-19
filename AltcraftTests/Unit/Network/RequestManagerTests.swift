//
//  RequestManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
* RequestManagerTests
*
* Positive scenarios:
* - test_1: responseProcessing success 2xx → returns Event with mapped code.
* - test_2: responseProcessing server error 5xx → returns RetryEvent with mapped code.
* - test_3: responseProcessing client error 4xx → returns ErrorEvent with mapped code.
* - test_4: redirect delegate preserves critical headers.
* - test_5: sendRequest with mock URLSession success 200 → maps success pair.
* - test_6: sendRequest with mock URLSession server error 5xx → maps retry pair.
* - test_7: sendRequest with mock URLSession network error → maps retry event.
* - test_8: responseProcessing mobile event success → uses name in pair.
*
*/
final class RequestManagerTests: IsolatedTestCase {

    private final class RequestManagerAdapter {
        private let manager: RequestManager
        private let session: URLSessioning

        init(
            manager: RequestManager = RequestManager.shared,
            session: URLSessioning
        ) {
            self.manager = manager
            self.session = session
        }

        func sendRequest(
            url: URL,
            requestName: String,
            uid: String? = nil,
            pushEventType: String? = nil,
            mobileEventName: String? = nil
        ) async -> Event {
            await withCheckedContinuation { continuation in
                session.makeDownloadTask(with: url) { tempURL, response, error in
                    if let error {
                        continuation.resume(
                            returning: retryEvent("sendRequestAdapter: \(requestName)", error: error)
                        )
                        return
                    }

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.resume(
                            returning: retryEvent("sendRequestAdapter: \(requestName)", error: invalidResponseFormat)
                        )
                        return
                    }

                    let data = tempURL.flatMap { try? Data(contentsOf: $0) }

                    let event = self.manager.responseProcessing(
                        response: httpResponse,
                        data: data,
                        requestName: requestName,
                        uid: uid,
                        type: pushEventType,
                        name: mobileEventName
                    )

                    continuation.resume(returning: event)
                }.resume()
            }
        }
    }

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://example.com/api")!,
            statusCode: code,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
    }

    private func json(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [])
    }

    private func normalize(_ raw: String?) -> String {
        guard let raw else { return "" }

        if let index = raw.firstIndex(of: "(") {
            return String(raw[..<index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return raw.hasSuffix("()")
            ? String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            : raw
    }

    /// responseProcessing success 2xx returns Event with mapped code
    func test_1_responseProcessing_success_2xx_returns_event_with_mapped_code() {
        let manager = RequestManager.shared

        let event = manager.responseProcessing(
            response: http(200),
            data: json([:]),
            requestName: Constants.RequestName.pushEvent,
            uid: "U1",
            type: Constants.PushEvents.delivery,
            name: nil
        )

        XCTAssertTrue(Swift.type(of: event) == Event.self)
        XCTAssertEqual(event.eventCode, 236)
        XCTAssertEqual(normalize(event.function), "responseProcessing")
        XCTAssertNotNil(event.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }

    /// responseProcessing server error 5xx returns RetryEvent with mapped code
    func test_2_responseProcessing_server_error_5xx_returns_retry_event_with_mapped_code() {
        let manager = RequestManager.shared

        let event = manager.responseProcessing(
            response: http(503),
            data: json(["error": 123, "errorText": "boom"]),
            requestName: Constants.RequestName.subscribe
        )

        XCTAssertTrue(Swift.type(of: event) == RetryEvent.self)
        XCTAssertEqual(event.eventCode, 530)
        XCTAssertTrue((event.message ?? "").contains("http code: 503"))
        XCTAssertEqual(normalize(event.function), "responseProcessing")
    }

    /// responseProcessing client error 4xx returns ErrorEvent with mapped code
    func test_3_responseProcessing_client_error_4xx_returns_error_event_with_mapped_code() {
        let manager = RequestManager.shared

        let event = manager.responseProcessing(
            response: http(409),
            data: json(["error": 12, "errorText": "bad"]),
            requestName: Constants.RequestName.tokenUpdate
        )

        XCTAssertTrue(Swift.type(of: event) == ErrorEvent.self)
        XCTAssertEqual(event.eventCode, 433)
        XCTAssertEqual(normalize(event.function), "responseProcessing")
        XCTAssertNotNil(event.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }

    /// redirect delegate preserves critical headers
    func test_4_redirect_delegate_preserves_critical_headers() {
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

        let redirectResponse = HTTPURLResponse(
            url: firstURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": secondURL.absoluteString]
        )!

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

    /// sendRequest with mock URLSession success 200 maps success pair
    func test_5_send_request_with_mock_url_session_success_200_maps_success_pair() async {
        let body = json([:])
        let mockSession = MockURLSession(result: .success(body), statusCode: 200)
        let adapter = RequestManagerAdapter(session: mockSession)

        let event = await adapter.sendRequest(
            url: URL(string: "https://mock.local/success")!,
            requestName: Constants.RequestName.subscribe
        )

        XCTAssertTrue(Swift.type(of: event) == Event.self)
        XCTAssertEqual(event.eventCode, 230)
        XCTAssertEqual(normalize(event.function), "responseProcessing")
    }

    /// sendRequest with mock URLSession server error 5xx maps retry pair
    func test_6_send_request_with_mock_url_session_server_error_5xx_maps_retry_pair() async {
        let body = json([:])
        let mockSession = MockURLSession(result: .success(body), statusCode: 503)
        let adapter = RequestManagerAdapter(session: mockSession)

        let event = await adapter.sendRequest(
            url: URL(string: "https://mock.local/5xx")!,
            requestName: Constants.RequestName.pushEvent,
            uid: "U5",
            pushEventType: Constants.PushEvents.delivery
        )

        XCTAssertTrue(Swift.type(of: event) == RetryEvent.self)
        XCTAssertEqual(event.eventCode, 536)
        XCTAssertEqual(normalize(event.function), "responseProcessing")
    }

    /// sendRequest with mock URLSession network error maps retry event
    func test_7_send_request_with_mock_url_session_network_error_maps_retry_event() async {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        let mockSession = MockURLSession(result: .failure(error), statusCode: 200)
        let adapter = RequestManagerAdapter(session: mockSession)

        let event = await adapter.sendRequest(
            url: URL(string: "https://mock.local/error")!,
            requestName: Constants.RequestName.tokenUpdate
        )

        XCTAssertTrue(Swift.type(of: event) == RetryEvent.self)
        XCTAssertEqual(
            normalize(event.function),
            "sendRequestAdapter: \(Constants.RequestName.tokenUpdate)"
        )
    }

    /// responseProcessing mobile event success uses name in pair
    func test_8_response_processing_mobile_event_success_uses_name_in_pair() {
        let manager = RequestManager.shared

        let event = manager.responseProcessing(
            response: http(200),
            data: json([:]),
            requestName: Constants.RequestName.mobileEvent,
            uid: "U8",
            type: nil,
            name: "open app"
        )

        XCTAssertTrue(Swift.type(of: event) == Event.self)
        XCTAssertEqual(event.eventCode, 237)
        XCTAssertEqual(normalize(event.function), "responseProcessing")
        XCTAssertNotNil(event.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }
}
