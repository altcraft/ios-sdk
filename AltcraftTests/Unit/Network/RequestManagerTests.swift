//
//  RequestManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * RequestManagerTests
 *
 * Positive scenarios:
 *  - test_1: responseProcessing success 2xx returns event with mapped code.
 *  - test_2: responseProcessing server error 5xx returns retry event with mapped code.
 *  - test_3: responseProcessing client error 4xx returns error event with mapped code.
 *  - test_4: redirect delegate preserves critical headers.
 *  - test_5: sendRequest with mock URLSession success 200 maps success pair.
 *  - test_6: sendRequest with mock URLSession server error 5xx maps retry pair.
 *  - test_7: sendRequest with mock URLSession network error maps retry event.
 *  - test_8: responseProcessing mobile event success uses name in pair.
 */
final class RequestManagerTests: XCTestCase {

    private final class RequestManagerAdapter {
        private let manager: RequestManager
        private let session: URLSessioning

        init(manager: RequestManager = RequestManager.shared, session: URLSessioning) {
            self.manager = manager
            self.session = session
        }

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

    private func http(_ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com/api")!,
                        statusCode: code,
                        httpVersion: "HTTP/1.1",
                        headerFields: [:])!
    }

    private func json(_ obj: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: obj, options: [])
    }

    private func normalize(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") { return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines) }
        return raw.hasSuffix("()") ? String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines) : raw
    }

    /// test_1: responseProcessing success 2xx returns event with mapped code
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
        XCTAssertEqual(ev.eventCode, 234)
        XCTAssertEqual(normalize(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp)
    }

    /// test_2: responseProcessing server error 5xx returns retry event with mapped code
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

    /// test_3: responseProcessing client error 4xx returns error event with mapped code
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

    /// test_4: redirect delegate preserves critical headers
    func test_4_redirect_delegate_preservesCriticalHeaders() {
        let manager = RequestManager.shared

        let firstURL  = URL(string: "https://stub.local/redirect")!
        let secondURL = URL(string: "https://stub.local/final")!

        var original = URLRequest(url: firstURL)
        original.httpMethod = "GET"
        original.setValue("Bearer SECRET", forHTTPHeaderField: Constants.HTTPHeader.authorization)
        original.setValue("RID-REDIR",    forHTTPHeaderField: Constants.HTTPHeader.requestId)
        original.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)

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

    /// test_5: sendRequest with mock URLSession success 200 maps success pair
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

    /// test_6: sendRequest with mock URLSession server error 5xx maps retry pair
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

    /// test_7: sendRequest with mock URLSession network error maps retry event
    func test_7_sendRequest_withMockURLSession_networkError_mapsRetryEvent() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let mock = MockURLSession(result: .failure(err), statusCode: 200)
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

    /// test_8: responseProcessing mobile event success uses name in pair
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
