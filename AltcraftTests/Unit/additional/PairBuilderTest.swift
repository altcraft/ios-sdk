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
 *  - test_1_errorPair_subscribe_5xx_usesMapped5xxCode
 *  - test_2_errorPair_update_4xx_usesMapped4xxCode
 *  - test_3_errorPair_pushEvent_5xx_includesTypeInMessage
 *  - test_4_errorPair_unsuspend_returns433
 *  - test_5_errorPair_status_returns434
 *  - test_6_errorPair_unknown_5xx_returns539WithUnknownPrefix
 *  - test_7_errorPair_unknown_4xx_returns439WithUnknownPrefix
 *  - test_8_successPair_allKnownRequests
 *  - test_9_successPair_pushEvent_appendsType
 *  - test_10_successPair_unknown_returnsZeroAndUnknownRequest
 *
 * Notes:
 *  - Response is passed as `nil` in error pair tests to keep construction minimal.
 *    (createErrorPair formats `error` as 0 and `errorText` as empty string in that case.)
 */
final class PairBuilderTest: XCTestCase {

    // ---------- Shorthand constants ----------
    private let reqSubscribe = Constants.RequestName.subscribe
    private let reqUpdate    = Constants.RequestName.update
    private let reqPushEvent = Constants.RequestName.pushEvent
    private let reqUnsuspend = Constants.RequestName.unsuspend
    private let reqStatus    = Constants.RequestName.status
    private let reqUnknown   = "unknown/op"

    private let anyType   = "delivery"
    private let http4xx   = 400
    private let http5xx   = 503

    // Assertion messages
    private let msgCodeMatch     = "Custom code must match expected value"
    private let msgMessageFormat = "Message must include expected fragments"
    private let msgUnknownPrefix = "Unknown branch must prefix message with 'unknown request:'"

    // Common expectations helpers
    private func expectBaseFragments(in message: String, request: String, http: Int, error: Int = 0, errorText: String = "") {
        XCTAssertTrue(message.contains("request: \(request)"), msgMessageFormat)
        XCTAssertTrue(message.contains("http code: \(http)"), msgMessageFormat)
        XCTAssertTrue(message.contains("error: \(error)"),    msgMessageFormat)
        XCTAssertTrue(message.contains("errorText: \(errorText)"), msgMessageFormat)
    }

    // ---------------------------------
    // createErrorPair(..)
    // ---------------------------------

    /// subscribe + 5xx → mapped 5xx code (530) and base message
    func test_1_errorPair_subscribe_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSubscribe, code: http5xx, response: nil, type: nil)
        XCTAssertEqual(code, 530, msgCodeMatch)
        expectBaseFragments(in: msg, request: reqSubscribe, http: http5xx)
        XCTAssertFalse(msg.hasPrefix("unknown request:"), msgUnknownPrefix)
    }

    /// update + 4xx → mapped 4xx code (431)
    func test_2_errorPair_update_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http4xx, response: nil, type: nil)
        XCTAssertEqual(code, 431, msgCodeMatch)
        expectBaseFragments(in: msg, request: reqUpdate, http: http4xx)
        XCTAssertFalse(msg.hasPrefix("unknown request:"), msgUnknownPrefix)
    }

    /// pushEvent + 5xx → mapped 5xx (532) and message contains type
    func test_3_errorPair_pushEvent_5xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http5xx, response: nil, type: anyType)
        XCTAssertEqual(code, 532, msgCodeMatch)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http5xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"), msgMessageFormat)
    }

    /// unsuspend → 433 regardless of HTTP code
    func test_4_errorPair_unsuspend_returns433() {
        let (code, msg) = createErrorPair(requestName: reqUnsuspend, code: http5xx, response: nil, type: nil)
        XCTAssertEqual(code, 433, msgCodeMatch)
        expectBaseFragments(in: msg, request: reqUnsuspend, http: http5xx)
    }

    /// status → 434 regardless of HTTP code
    func test_5_errorPair_status_returns434() {
        let (code, msg) = createErrorPair(requestName: reqStatus, code: http4xx, response: nil, type: nil)
        XCTAssertEqual(code, 434, msgCodeMatch)
        expectBaseFragments(in: msg, request: reqStatus, http: http4xx)
    }

    /// unknown + 5xx → 539 and message prefixed with "unknown request:"
    func test_6_errorPair_unknown_5xx_returns539WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http5xx, response: nil, type: nil)
        XCTAssertEqual(code, 539, msgCodeMatch)
        XCTAssertTrue(msg.hasPrefix("unknown request:"), msgUnknownPrefix)
        // Base fragments still must be present *after* the prefix
        expectBaseFragments(in: msg, request: reqUnknown, http: http5xx)
    }

    /// unknown + 4xx → 439 and message prefixed with "unknown request:"
    func test_7_errorPair_unknown_4xx_returns439WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http4xx, response: nil, type: nil)
        XCTAssertEqual(code, 439, msgCodeMatch)
        XCTAssertTrue(msg.hasPrefix("unknown request:"), msgUnknownPrefix)
        expectBaseFragments(in: msg, request: reqUnknown, http: http4xx)
    }

    // ---------------------------------
    // createSuccessPair(..)
    // ---------------------------------

    /// Success codes/messages for all known requests (without type)
    func test_8_successPair_allKnownRequests() {
        let s1 = createSuccessPair(requestName: reqSubscribe, type: nil)
        XCTAssertEqual(s1.0, 230)
        XCTAssertEqual(s1.1, Constants.SDKSuccessMessage.subscribeSuccess)

        let s2 = createSuccessPair(requestName: reqUpdate, type: nil)
        XCTAssertEqual(s2.0, 231)
        XCTAssertEqual(s2.1, Constants.SDKSuccessMessage.tokenUpdateSuccess)

        let s3 = createSuccessPair(requestName: reqUnsuspend, type: nil)
        XCTAssertEqual(s3.0, 233)
        XCTAssertEqual(s3.1, Constants.SDKSuccessMessage.pushUnSuspendSuccess)

        let s4 = createSuccessPair(requestName: reqStatus, type: nil)
        XCTAssertEqual(s4.0, 234)
        XCTAssertEqual(s4.1, Constants.SDKSuccessMessage.profileSuccess)
    }

    /// pushEvent success appends type to message (e.g., "/event/push/<type>")
    func test_9_successPair_pushEvent_appendsType() {
        let res = createSuccessPair(requestName: reqPushEvent, type: anyType)
        XCTAssertEqual(res.0, 232)
        XCTAssertTrue(res.1.hasPrefix(Constants.SDKSuccessMessage.pushEventDelivered))
        XCTAssertTrue(res.1.hasSuffix(anyType))
    }

    /// unknown request returns (0, "unknown request")
    func test_10_successPair_unknown_returnsZeroAndUnknownRequest() {
        let res = createSuccessPair(requestName: reqUnknown, type: nil)
        XCTAssertEqual(res.0, 0)
        XCTAssertEqual(res.1, "unknown request")
    }
}

