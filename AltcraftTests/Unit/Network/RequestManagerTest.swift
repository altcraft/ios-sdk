//
//  RequestManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * RequestManagerTests
 *
 * Coverage:
 *  - test_1_responseProcessing_success_2xx_returnsEvent_withMappedCode
 *  - test_2_responseProcessing_serverError_5xx_returnsRetryEvent_withMappedCode
 *  - test_3_responseProcessing_clientError_4xx_returnsErrorEvent_withMappedCode
 *  - test_4_redirect_delegate_preservesCriticalHeaders
 *  - test_5_sendRequest_withMockURLSession_success200_mapsSuccessPair
 *  - test_6_sendRequest_withMockURLSession_serverError_5xx_mapsRetryPair
 *  - test_7_sendRequest_withMockURLSession_networkError_mapsRetryEvent
 *  - test_8_responseProcessing_mobileEvent_success_usesNameInPair
 */
final class RequestManagerTests: XCTestCase {

    /// Small adapter to drive RequestManager.responseProcessing using URLSessioning.
    private final class RequestManagerAdapter {
        private let manager: RequestManager
        private let session: URLSessioning

        init(manager: RequestManager = RequestManager.shared, session: URLSessioning) {
            self.manager = manager
            self.session = session
        }

        /// Sends a fake request through the mock session and maps response via RequestManager.
        func sendRequest(
            url: URL,
            requestName: String,
            uid: String? = nil,
            type: String? = nil,
            name: String? = nil,
            completion: @escaping (Event) -> Void
        ) {
            session.makeDownloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    completion(retryEvent("sendRequestAdapter: \(requestName)", error: error))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(retryEvent("sendRequestAdapter: \(requestName)", error: invalidResponseFormat))
                    return
                }
                let data = tempURL.flatMap { try? Data(contentsOf: $0) }
                let ev = self.manager.responseProcessing(
                    response: http,
                    data: data,
                    requestName: requestName,
                    uid: uid,
                    type: type,
                    name: name
                )
                completion(ev)
            }.resume()
        }
    }

    /// Builds an HTTP response with the given status code.
    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com/api")!,
                        statusCode: code,
                        httpVersion: "HTTP/1.1",
                        headerFields: [:])!
    }

    /// Encodes a JSON payload for the body.
    private func json(_ obj: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: obj, options: [])
    }

    /// Normalizes a function name by stripping params and trailing "()".
    private func normalize(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") { return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) }
        return raw.hasSuffix("()") ? String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines) : raw
    }

    // ---- responseProcessing direct tests ----

    /// Verifies that 2xx maps to Event with the pushEvent success pair.
    func test_1_responseProcessing_success_2xx_returnsEvent_withMappedCode() {
        let mgr = RequestManager.shared
        let ev = mgr.responseProcessing(
            response: http(200),
            data: json([:]),
            requestName: Constants.RequestName.pushEvent,
            uid: "U1",
            type: Constants.PushEvents.delivery,
            name: nil
        )
        XCTAssertTrue(type(of: ev) == Event.self)
        XCTAssertEqual(ev.eventCode, 234) // pushEvent success
        XCTAssertEqual(normalize(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }

    /// Verifies that 5xx maps to RetryEvent with mapped error pair (subscribe).
    func test_2_responseProcessing_serverError_5xx_returnsRetryEvent_withMappedCode() {
        let mgr = RequestManager.shared
        let ev = mgr.responseProcessing(
            response: http(503),
            data: json(["error": 123, "errorText": "boom"]),
            requestName: Constants.RequestName.subscribe
        )
        XCTAssertTrue(type(of: ev) == RetryEvent.self)
        XCTAssertEqual(ev.eventCode, 530)
        XCTAssertTrue((ev.message ?? "").contains("http code: 503"))
    }

    /// Verifies that 4xx maps to ErrorEvent with mapped error pair (update).
    func test_3_responseProcessing_clientError_4xx_returnsErrorEvent_withMappedCode() {
        let mgr = RequestManager.shared
        let ev = mgr.responseProcessing(
            response: http(409),
            data: json(["error": 12, "errorText": "bad"]),
            requestName: Constants.RequestName.update
        )
        XCTAssertTrue(type(of: ev) == ErrorEvent.self)
        XCTAssertEqual(ev.eventCode, 431)
        XCTAssertEqual(normalize(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }

    // ---- delegate redirect test ----

    /// Ensures the delegate preserves Authorization, Request-ID, and Content-Type headers on redirect.
    func test_4_redirect_delegate_preservesCriticalHeaders() {
        let manager = RequestManager.shared

        let firstURL  = URL(string: "https://stub.local/redirect")!
        let secondURL = URL(string: "https://stub.local/final")!

        var original = URLRequest(url: firstURL)
        original.httpMethod = "GET"
        original.setValue("Bearer SECRET", forHTTPHeaderField: Constants.HTTPHeader.authorization)
        original.setValue("RID-REDIR",    forHTTPHeaderField: Constants.HTTPHeader.requestId)
        original.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)

        // Create a real task so originalRequest is valid (no network start needed)
        let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil)
        let task = session.dataTask(with: original)

        let redirectResponse = HTTPURLResponse(
            url: firstURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": secondURL.absoluteString]
        )!

        var newReq = URLRequest(url: secondURL)
        newReq.httpMethod = "GET"

        let exp = expectation(description: "delegate returns modified request")

        manager.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: redirectResponse,
            newRequest: newReq
        ) { modified in
            XCTAssertNotNil(modified)
            let r = modified!

            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer SECRET")
            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-REDIR")
            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.contentType), "application/json")
            XCTAssertEqual(r.url, secondURL)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that sendRequest path maps 200 to subscribe success (230).
    func test_5_sendRequest_withMockURLSession_success200_mapsSuccessPair() {
        let body = json([:])
        let mock = MockURLSession(result: .success(body), statusCode: 200)
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "success 200 via MockURLSession")
        adapter.sendRequest(url: URL(string: "https://mock.local/success")!,
                            requestName: Constants.RequestName.subscribe) { ev in
            XCTAssertTrue(type(of: ev) == Event.self)
            XCTAssertEqual(ev.eventCode, 230)
            XCTAssertEqual(self.normalize(ev.function), "responseProcessing")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that sendRequest path maps 503 to RetryEvent for pushEvent (534).
    func test_6_sendRequest_withMockURLSession_serverError_5xx_mapsRetryPair() {
        let body = json([:])
        let mock = MockURLSession(result: .success(body), statusCode: 503)
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "server error 5xx via MockURLSession")
        adapter.sendRequest(url: URL(string: "https://mock.local/5xx")!,
                            requestName: Constants.RequestName.pushEvent,
                            uid: "U5",
                            type: Constants.PushEvents.delivery) { ev in
            XCTAssertTrue(type(of: ev) == RetryEvent.self)
            XCTAssertEqual(ev.eventCode, 534)
            XCTAssertEqual(self.normalize(ev.function), "responseProcessing")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that transport error yields RetryEvent on the adapter path.
    func test_7_sendRequest_withMockURLSession_networkError_mapsRetryEvent() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let mock = MockURLSession(result: .failure(err), statusCode: 200) // status ignored on failure
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "network error via MockURLSession")
        adapter.sendRequest(url: URL(string: "https://mock.local/error")!,
                            requestName: Constants.RequestName.update) { ev in
            XCTAssertTrue(type(of: ev) == RetryEvent.self)
            XCTAssertEqual(self.normalize(ev.function), "sendRequestAdapter: \(Constants.RequestName.update)")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    /// Verifies that 2xx for mobileEvent uses name in success pair (235).
    func test_8_responseProcessing_mobileEvent_success_usesNameInPair() {
        let mgr = RequestManager.shared
        let ev = mgr.responseProcessing(
            response: http(200),
            data: json([:]),
            requestName: Constants.RequestName.mobileEvent,
            uid: "U8",
            type: nil,
            name: "open app"
        )
        XCTAssertTrue(type(of: ev) == Event.self)
        XCTAssertEqual(ev.eventCode, 235)
        XCTAssertEqual(normalize(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }
}

