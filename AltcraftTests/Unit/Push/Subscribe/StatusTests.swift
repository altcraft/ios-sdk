//
//  StatusTests.swift
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
* StatusTests
*
* Positive scenarios:
* - test_1: Invalid provider returns nil and emits error from getStatusOfLatestSubscriptionForProvider.
* - test_2: Latest subscription status returns nil or empty response when request cannot be completed.
* - test_3: Current subscription status returns nil or empty response when request cannot be completed.
* - test_4: Latest subscription status for nil provider returns nil or empty response when request cannot be completed.
*
*/
final class StatusTests: IsolatedTestCase {

    private typealias StatusResponse = ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >

    /// Captures emitted SDK events.
    private final class EventSpy {
        private let lock = NSLock()
        private(set) var events: [Event] = []

        var onEvent: ((Event) -> Void)?

        func start() {
            SDKEvents.shared.subscribe { [weak self] event in
                guard let self else { return }

                lock.lock()
                events.append(event)
                lock.unlock()

                onEvent?(event)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
        }

        func snapshot() -> [Event] {
            lock.lock()
            defer { lock.unlock() }

            return events
        }
    }

    private func normalizeFunctionName(_ raw: String?) -> String {
        guard let rawElse: String = raw else {
            return ""
        }

        var s = rawElse
        if let spaceIdx = s.firstIndex(of: " ") {
            let candidate = s[..<spaceIdx]
            if candidate.first == "[" && candidate.last == "]" {
                s = String(s[s.index(after: spaceIdx)...])
            }
        }

        if let idx = s.firstIndex(of: "(") {
            return String(s[..<idx])
        }

        return s.hasSuffix("()")
            ? String(s.dropLast(2))
            : s
    }

    private func assertNilOrEmptyStatusResponse(
        _ result: StatusResponse?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let result else {
            return
        }

        XCTAssertNil(result.httpCode, file: file, line: line)
        XCTAssertNil(result.response, file: file, line: line)
    }

    /// test_1: Invalid provider returns nil and emits error from getStatusOfLatestSubscriptionForProvider
    func test_1_getStatusOfLatestSubscriptionForProvider_invalidProvider_returnsNil_andEmitsError() async {
        let spy = EventSpy()
        let expectation = XCTestExpectation(
            description: "Invalid provider error event emitted"
        )

        spy.onEvent = { [weak self] event in
            guard let self else { return }
            guard event is ErrorEvent else { return }

            let functionName = self.normalizeFunctionName(event.function)

            if functionName == "getStatusOfLatestSubscriptionForProvider" {
                expectation.fulfill()
            }
        }

        spy.start()
        defer { spy.stop() }

        let result = await PushStatusProcess.shared.getStatusOfLatestSubscriptionForProvider(
            provider: "__invalid__"
        )

        XCTAssertNil(result)

        await fulfillment(
            of: [expectation],
            timeout: 1.0
        )
    }

    /// test_2: Latest subscription status returns nil or empty response when request cannot be completed
    func test_2_getStatusOfLatestSubscription_returnsNilOrEmptyResponse() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let result = await PushStatusProcess.shared.getStatusOfLatestSubscription()

        assertNilOrEmptyStatusResponse(result)
    }

    /// test_3: Current subscription status returns nil or empty response when request cannot be completed
    func test_3_getStatusForCurrentSubscription_returnsNilOrEmptyResponse() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let result = await PushStatusProcess.shared.getStatusForCurrentSubscription()

        assertNilOrEmptyStatusResponse(result)
    }

    /// test_4: Latest subscription status for nil provider returns nil or empty response when request cannot be completed
    func test_4_getStatusOfLatestSubscriptionForProvider_nilProvider_returnsNilOrEmptyResponse() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let result = await PushStatusProcess.shared.getStatusOfLatestSubscriptionForProvider(
            provider: nil
        )

        assertNilOrEmptyStatusResponse(result)
    }
}
