//
//  PairBuilderTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * PairBuilderTest
 *
 * Positive scenarios:
 *  - test_1: subscribe request with 5xx error → returns mapped 5xx code (530) and base message.
 *  - test_2: subscribe request with 4xx error → returns mapped 4xx code (430) and base message.
 *  - test_3: update request with 5xx error → returns mapped 5xx code (531) and base message.
 *  - test_4: update request with 4xx error → returns mapped 4xx code (431) and base message.
 *  - test_5: pushEvent request with 5xx error → returns mapped 5xx code (534) and includes event type in message.
 *  - test_6: pushEvent request with 4xx error → returns mapped 4xx code (434) and includes event type in message.
 *  - test_7: mobileEvent request with 5xx error → returns mapped 5xx code (535) and includes event name in message.
 *  - test_8: mobileEvent request with 4xx error → returns mapped 4xx code (435) and includes event name in message.
 *  - test_9: unsuspend request with any error → returns fixed code (432) and base message.
 *  - test_10: status request with any error → returns fixed code (433) and base message.
 *  - test_11: unknown request with 5xx error → returns 539 code and "unknown request:" prefix in message.
 *  - test_12: unknown request with 4xx error → returns 439 code and "unknown request:" prefix in message.
 *  - test_13: success pair for known requests → returns appropriate success codes and messages.
 *  - test_14: pushEvent success → returns success code (234) and message with appended event type.
 *  - test_15: mobileEvent success → returns success code (235) and message with appended event name.
 *  - test_16: unknown request success → returns zero code and "unknown request" message.
 */
final class PairBuilderTest: XCTestCase {

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

    /// subscribe + 5xx → mapped 5xx code (530)
    func test_1_errorPair_subscribe_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSubscribe, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 530)
        expectBaseFragments(in: msg, request: reqSubscribe, http: http5xx)
    }

    /// subscribe + 4xx → mapped 4xx code (430)
    func test_2_errorPair_subscribe_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSubscribe, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 430)
        expectBaseFragments(in: msg, request: reqSubscribe, http: http4xx)
    }

    /// update + 5xx → mapped 5xx code (531)
    func test_3_errorPair_update_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 531)
        expectBaseFragments(in: msg, request: reqUpdate, http: http5xx)
    }

    /// update + 4xx → mapped 4xx code (431)
    func test_4_errorPair_update_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 431)
        expectBaseFragments(in: msg, request: reqUpdate, http: http4xx)
    }

    /// pushEvent + 5xx → mapped 5xx (534) and message contains type
    func test_5_errorPair_pushEvent_5xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http5xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 534)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http5xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// pushEvent + 4xx → mapped 4xx (434) and message contains type
    func test_6_errorPair_pushEvent_4xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http4xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 434)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http4xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// mobileEvent + 5xx → mapped 5xx (535) and message contains name
    func test_7_errorPair_mobileEvent_5xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http5xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 535)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http5xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// mobileEvent + 4xx → mapped 4xx (435) and message contains name
    func test_8_errorPair_mobileEvent_4xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http4xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 435)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http4xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// unsuspend → 432 regardless of HTTP code
    func test_9_errorPair_unsuspend_returns432() {
        let (code, msg) = createErrorPair(requestName: reqUnsuspend, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 432)
        expectBaseFragments(in: msg, request: reqUnsuspend, http: http5xx)
    }

    /// status → 433 regardless of HTTP code
    func test_10_errorPair_status_returns433() {
        let (code, msg) = createErrorPair(requestName: reqStatus, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 433)
        expectBaseFragments(in: msg, request: reqStatus, http: http4xx)
    }

    /// unknown + 5xx → 539 and message prefixed with "unknown request:"
    func test_11_errorPair_unknown_5xx_returns539WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 539)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http5xx)
    }

    /// unknown + 4xx → 439 and message prefixed with "unknown request:"
    func test_12_errorPair_unknown_4xx_returns439WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 439)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http4xx)
    }

    // MARK: - createSuccessPair Tests

    /// Success codes/messages for all known requests
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

    /// pushEvent success appends type to message
    func test_14_successPair_pushEvent_appendsType() {
        let result = createSuccessPair(requestName: reqPushEvent, type: anyType, name: nil)
        XCTAssertEqual(result.0, 234)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.pushEventDelivered + anyType)
    }

    /// mobileEvent success appends name to message
    func test_15_successPair_mobileEvent_appendsName() {
        let result = createSuccessPair(requestName: reqMobileEvent, type: nil, name: anyName)
        XCTAssertEqual(result.0, 235)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.mobileEventDelivered + anyName)
    }

    /// unknown request returns (0, "unknown request")
    func test_16_successPair_unknown_returnsZeroAndUnknownRequest() {
        let result = createSuccessPair(requestName: reqUnknown, type: nil, name: nil)
        XCTAssertEqual(result.0, 0)
        XCTAssertEqual(result.1, "unknown request")
    }
}

