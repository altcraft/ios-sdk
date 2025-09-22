//
//  RequestManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * RequestManagerTests (iOS 13 compatible)
 *
 * Coverage (explicit):
 *  - test_1_responseProcessing_success_2xx_returnsEvent_withMappedCode
 *  - test_2_responseProcessing_serverError_5xx_returnsRetryEvent_withMappedCode
 *  - test_3_responseProcessing_clientError_4xx_returnsErrorEvent_withMappedCode
 *  - test_4_redirect_delegate_preservesCriticalHeaders
 *  - test_5_sendRequest_withMockURLSession_success200_mapsSuccessPair
 *  - test_6_sendRequest_withMockURLSession_serverError_5xx_mapsRetryPair
 *  - test_7_sendRequest_withMockURLSession_networkError_mapsRetryEvent
 */
final class RequestManagerTests: XCTestCase {

    // MARK: - Test Adapter over URLSessioning

    /// A tiny adapter used only in tests to drive RequestManager.responseProcessing
    /// using a URLSessioning (MockURLSession in tests, real URLSession in prod if desired).
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
            completion: @escaping (Event) -> Void
        ) {
            // Use the abstraction method defined in URLSessioning.
            session.makeDownloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    completion(retryEvent("sendRequestAdapter: \(requestName)", error: error))
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(retryEvent("sendRequestAdapter: \(requestName)", error: invalidResponseFormat))
                    return
                }

                let data: Data? = tempURL.flatMap { try? Data(contentsOf: $0) }

                let ev = self.manager.responseProcessing(
                    response: http,
                    data: data,
                    requestName: requestName,
                    uid: uid,
                    type: type
                )
                completion(ev)
            }.resume()
        }
    }

    // MARK: - Helpers

    /// Normalizes a function name by stripping parameters and trailing "()".
    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let raw = raw else { return "" }
        if let idx = raw.firstIndex(of: "(") {
            return String(raw[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.hasSuffix("()") {
            return String(raw.dropLast(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - responseProcessing direct tests

    func test_1_responseProcessing_success_2xx_returnsEvent_withMappedCode() {
        let mgr = RequestManager.shared

        let url = URL(string: "https://example.com")!
        let res = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let ev = mgr.responseProcessing(
            response: res,
            data: nil,
            requestName: Constants.RequestName.pushEvent,
            uid: "U1",
            type: Constants.PushEvents.open
        )

        XCTAssertFalse(ev is ErrorEvent)
        XCTAssertFalse(ev is RetryEvent)
        XCTAssertEqual(ev.eventCode, 232, "Success code via createSuccessPair for pushEvent")
        XCTAssertEqual(normalizeFunctionName(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] ?? nil)
    }

    func test_2_responseProcessing_serverError_5xx_returnsRetryEvent_withMappedCode() {
        let mgr = RequestManager.shared

        let url = URL(string: "https://example.com")!
        let res = HTTPURLResponse(url: url, statusCode: 503, httpVersion: nil, headerFields: nil)!
        let ev = mgr.responseProcessing(
            response: res,
            data: nil,
            requestName: Constants.RequestName.subscribe,
            uid: "U2",
            type: nil
        )

        XCTAssertTrue(ev is RetryEvent, "5xx -> RetryEvent")
        XCTAssertEqual(ev.eventCode, 530, "Mapped 5xx code for subscribe")
        XCTAssertEqual(normalizeFunctionName(ev.function), "responseProcessing")
    }

    func test_3_responseProcessing_clientError_4xx_returnsErrorEvent_withMappedCode() {
        let mgr = RequestManager.shared

        let url = URL(string: "https://example.com")!
        let res = HTTPURLResponse(url: url, statusCode: 409, httpVersion: nil, headerFields: nil)!
        let body = try! JSONSerialization.data(withJSONObject: ["error": 12, "errorText": "bad"], options: [])
        let ev = mgr.responseProcessing(
            response: res,
            data: body,
            requestName: Constants.RequestName.update,
            uid: "U3",
            type: nil
        )

        XCTAssertTrue(ev is ErrorEvent, "4xx -> ErrorEvent")
        XCTAssertEqual(ev.eventCode, 431, "Mapped 4xx code for update")
        XCTAssertEqual(normalizeFunctionName(ev.function), "responseProcessing")
        XCTAssertNotNil(ev.value?[Constants.MapKeys.responseWithHttp] ?? nil)
    }

    // MARK: - delegate redirect test

    func test_4_redirect_delegate_preservesCriticalHeaders() {
        let manager = RequestManager.shared

        let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: nil)

        let firstURL = URL(string: "https://stub.local/redirect")!
        let secondURL = URL(string: "https://stub.local/final")!

        var original = URLRequest(url: firstURL)
        original.httpMethod = "GET"
        original.setValue("Bearer SECRET", forHTTPHeaderField: Constants.HTTPHeader.authorization)
        original.setValue("RID-REDIR", forHTTPHeaderField: Constants.HTTPHeader.requestId)
        original.setValue("application/json", forHTTPHeaderField: Constants.HTTPHeader.contentType)

        let task = session.dataTask(with: original)

        let redirectResponse = HTTPURLResponse(
            url: firstURL,
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": secondURL.absoluteString]
        )!

        var newReq = URLRequest(url: secondURL)
        newReq.httpMethod = "GET"

        let done = expectation(description: "delegate returns modified request")

        manager.urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: redirectResponse,
            newRequest: newReq
        ) { modified in
            XCTAssertNotNil(modified, "Redirected request must be provided")
            let r = modified!

            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.authorization), "Bearer SECRET")
            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.requestId), "RID-REDIR")
            XCTAssertEqual(r.value(forHTTPHeaderField: Constants.HTTPHeader.contentType), "application/json")
            XCTAssertEqual(r.url, secondURL)
            done.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - MockURLSession-driven tests via adapter

    func test_5_sendRequest_withMockURLSession_success200_mapsSuccessPair() {
        let body = try! JSONSerialization.data(withJSONObject: [:], options: [])
        let mock = MockURLSession(result: .success(body), statusCode: 200)
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "success 200 via MockURLSession")
        let url = URL(string: "https://mock.local/success")!

        adapter.sendRequest(url: url, requestName: Constants.RequestName.subscribe) { ev in
            XCTAssertFalse(ev is ErrorEvent)
            XCTAssertFalse(ev is RetryEvent)
            XCTAssertEqual(ev.eventCode, 230, "subscribe success code")
            XCTAssertEqual(self.normalizeFunctionName(ev.function), "responseProcessing")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func test_6_sendRequest_withMockURLSession_serverError_5xx_mapsRetryPair() {
        let body = try! JSONSerialization.data(withJSONObject: [:], options: [])
        let mock = MockURLSession(result: .success(body), statusCode: 503)
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "server error 5xx via MockURLSession")
        let url = URL(string: "https://mock.local/5xx")!

        adapter.sendRequest(url: url, requestName: Constants.RequestName.pushEvent, uid: "U5", type: Constants.PushEvents.delivery) { ev in
            XCTAssertTrue(ev is RetryEvent)
            XCTAssertEqual(ev.eventCode, 532, "pushEvent 5xx mapped retry code")
            XCTAssertEqual(self.normalizeFunctionName(ev.function), "responseProcessing")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func test_7_sendRequest_withMockURLSession_networkError_mapsRetryEvent() {
        let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        let mock = MockURLSession(result: .failure(err), statusCode: 200) // status ignored on failure
        let adapter = RequestManagerAdapter(session: mock)

        let exp = expectation(description: "network error via MockURLSession")
        let url = URL(string: "https://mock.local/error")!

        adapter.sendRequest(url: url, requestName: Constants.RequestName.update) { ev in
            XCTAssertTrue(ev is RetryEvent, "transport error should yield RetryEvent")
            XCTAssertEqual(self.normalizeFunctionName(ev.function), "sendRequestAdapter: \(Constants.RequestName.update)")
            exp.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }
}

