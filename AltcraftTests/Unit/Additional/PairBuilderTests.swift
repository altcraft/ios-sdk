//
//  PairBuilderTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PairBuilderTests
 *
 * Positive scenarios:
 *  - test_1: Subscribe request with 5xx error returns mapped 5xx code and base message.
 *  - test_2: Subscribe request with 4xx error returns mapped 4xx code and base message.
 *  - test_3: Update request with 5xx error returns mapped 5xx code and base message.
 *  - test_4: Update request with 4xx error returns mapped 4xx code and base message.
 *  - test_5: Push event request with 5xx error returns mapped 5xx code and includes event type in message.
 *  - test_6: Push event request with 4xx error returns mapped 4xx code and includes event type in message.
 *  - test_7: Mobile event request with 5xx error returns mapped 5xx code and includes event name in message.
 *  - test_8: Mobile event request with 4xx error returns mapped 4xx code and includes event name in message.
 *  - test_9: Unsuspend request with any error returns fixed code and base message.
 *  - test_10: Status request with any error returns fixed code and base message.
 *  - test_11: Unknown request with 5xx error returns 539 code and unknown request prefix in message.
 *  - test_12: Unknown request with 4xx error returns 439 code and unknown request prefix in message.
 *  - test_13: Success pair for known requests returns appropriate success codes and messages.
 *  - test_14: Push event success returns success code and message with appended event type.
 *  - test_15: Mobile event success returns success code and message with appended event name.
 *  - test_16: Unknown request success returns zero code and unknown request message.
 */
final class PairBuilderTests: XCTestCase {

    private let reqSubscribe = Constants.RequestName.subscribe
    private let reqUpdate = Constants.RequestName.update
    private let reqPushEvent = Constants.RequestName.pushEvent
    private let reqMobileEvent = Constants.RequestName.mobileEvent
    private let reqUnsuspend = Constants.RequestName.unsuspend
    private let reqStatus = Constants.RequestName.status
    private let reqUnknown = "unknown/op"

    private let anyType = "delivery"
    private let anyName = "test_event"
    private let http4xx = 400
    private let http5xx = 503

    private func expectBaseFragments(in message: String, request: String, http: Int, error: Int = 0, errorText: String = "") {
        XCTAssertTrue(message.contains("request: \(request)"))
        XCTAssertTrue(message.contains("http code: \(http)"))
        XCTAssertTrue(message.contains("error: \(error)"))
        XCTAssertTrue(message.contains("errorText: \(errorText)"))
    }

    /// test_1: Subscribe request with 5xx error returns mapped 5xx code and base message
    func test_1_errorPair_subscribe_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSubscribe, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 530)
        expectBaseFragments(in: msg, request: reqSubscribe, http: http5xx)
    }

    /// test_2: Subscribe request with 4xx error returns mapped 4xx code and base message
    func test_2_errorPair_subscribe_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSubscribe, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 430)
        expectBaseFragments(in: msg, request: reqSubscribe, http: http4xx)
    }

    /// test_3: Update request with 5xx error returns mapped 5xx code and base message
    func test_3_errorPair_update_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 531)
        expectBaseFragments(in: msg, request: reqUpdate, http: http5xx)
    }

    /// test_4: Update request with 4xx error returns mapped 4xx code and base message
    func test_4_errorPair_update_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 431)
        expectBaseFragments(in: msg, request: reqUpdate, http: http4xx)
    }

    /// test_5: Push event request with 5xx error returns mapped 5xx code and includes event type in message
    func test_5_errorPair_pushEvent_5xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http5xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 534)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http5xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// test_6: Push event request with 4xx error returns mapped 4xx code and includes event type in message
    func test_6_errorPair_pushEvent_4xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http4xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 434)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http4xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// test_7: Mobile event request with 5xx error returns mapped 5xx code and includes event name in message
    func test_7_errorPair_mobileEvent_5xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http5xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 535)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http5xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// test_8: Mobile event request with 4xx error returns mapped 4xx code and includes event name in message
    func test_8_errorPair_mobileEvent_4xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http4xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 435)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http4xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// test_9: Unsuspend request with any error returns fixed code and base message
    func test_9_errorPair_unsuspend_returns432() {
        let (code, msg) = createErrorPair(requestName: reqUnsuspend, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 432)
        expectBaseFragments(in: msg, request: reqUnsuspend, http: http5xx)
    }

    /// test_10: Status request with any error returns fixed code and base message
    func test_10_errorPair_status_returns433() {
        let (code, msg) = createErrorPair(requestName: reqStatus, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 433)
        expectBaseFragments(in: msg, request: reqStatus, http: http4xx)
    }

    /// test_11: Unknown request with 5xx error returns 539 code and unknown request prefix in message
    func test_11_errorPair_unknown_5xx_returns539WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 539)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http5xx)
    }

    /// test_12: Unknown request with 4xx error returns 439 code and unknown request prefix in message
    func test_12_errorPair_unknown_4xx_returns439WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 439)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http4xx)
    }

    /// test_13: Success pair for known requests returns appropriate success codes and messages
    func test_13_successPair_allKnownRequests() {
        let s1 = createSuccessPair(requestName: reqSubscribe, type: nil, name: nil)
        XCTAssertEqual(s1.0, 230)
        XCTAssertEqual(s1.1, Constants.SDKSuccessMessage.subscribeSuccess)

        let s2 = createSuccessPair(requestName: reqUpdate, type: nil, name: nil)
        XCTAssertEqual(s2.0, 231)
        XCTAssertEqual(s2.1, Constants.SDKSuccessMessage.tokenUpdateSuccess)

        let s3 = createSuccessPair(requestName: reqUnsuspend, type: nil, name: nil)
        XCTAssertEqual(s3.0, 232)
        XCTAssertEqual(s3.1, Constants.SDKSuccessMessage.pushUnSuspendSuccess)

        let s4 = createSuccessPair(requestName: reqStatus, type: nil, name: nil)
        XCTAssertEqual(s4.0, 233)
        XCTAssertEqual(s4.1, Constants.SDKSuccessMessage.statusSuccess)
    }

    /// test_14: Push event success returns success code and message with appended event type
    func test_14_successPair_pushEvent_appendsType() {
        let result = createSuccessPair(requestName: reqPushEvent, type: anyType, name: nil)
        XCTAssertEqual(result.0, 234)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.pushEventDelivered + anyType)
    }

    /// test_15: Mobile event success returns success code and message with appended event name
    func test_15_successPair_mobileEvent_appendsName() {
        let result = createSuccessPair(requestName: reqMobileEvent, type: nil, name: anyName)
        XCTAssertEqual(result.0, 235)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.mobileEventDelivered + anyName)
    }

    /// test_16: Unknown request success returns zero code and unknown request message
    func test_16_successPair_unknown_returnsZeroAndUnknownRequest() {
        let result = createSuccessPair(requestName: reqUnknown, type: nil, name: nil)
        XCTAssertEqual(result.0, 0)
        XCTAssertEqual(result.1, "unknown request")
    }
}
