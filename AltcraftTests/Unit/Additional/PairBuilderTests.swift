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
 *  - test_3: Suspend request with 5xx error returns mapped 5xx code and base message.
 *  - test_4: Suspend request with 4xx error returns mapped 4xx code and base message.
 *  - test_5: Unsubscribe request with 5xx error returns mapped 5xx code and base message.
 *  - test_6: Unsubscribe request with 4xx error returns mapped 4xx code and base message.
 *  - test_7: Update request with 5xx error returns mapped 5xx code and base message.
 *  - test_8: Update request with 4xx error returns mapped 4xx code and base message.
 *  - test_9: Push event request with 5xx error returns mapped 5xx code and includes event type in message.
 *  - test_10: Push event request with 4xx error returns mapped 4xx code and includes event type in message.
 *  - test_11: Mobile event request with 5xx error returns mapped 5xx code and includes event name in message.
 *  - test_12: Mobile event request with 4xx error returns mapped 4xx code and includes event name in message.
 *  - test_13: Unsuspend request with any error returns fixed code and base message.
 *  - test_14: Status request with any error returns fixed code and base message.
 *  - test_15: Unknown request with 5xx error returns 539 code and unknown request prefix in message.
 *  - test_16: Unknown request with 4xx error returns 439 code and unknown request prefix in message.
 *  - test_17: Success pair for known requests returns appropriate success codes and messages.
 *  - test_18: Push event success returns success code and message with appended event type.
 *  - test_19: Mobile event success returns success code and message with appended event name.
 *  - test_20: Unknown request success returns zero code and unknown request message.
 *  - test_21: getRequestMessages returns both error and success pairs consistent with builders.
 *  - test_22: Profile update request with 5xx error returns mapped 5xx code and base message.
 *  - test_23: Profile update request with 4xx error returns mapped 4xx code and base message.
 *  - test_24: Success pair for profile update returns code and message.
 *  - test_25: getRequestMessages for mobile event returns both error and success.
 *  - test_26: getRequestMessages for profile update returns both error and success.
 */
final class PairBuilderTests: IsolatedTestCase {

    private let reqSubscribe = Constants.RequestName.subscribe
    private let reqSuspend = Constants.RequestName.suspend
    private let reqUnsubscribe = Constants.RequestName.unsubscribe
    private let reqUpdate = Constants.RequestName.tokenUpdate
    private let reqPushEvent = Constants.RequestName.pushEvent
    private let reqMobileEvent = Constants.RequestName.mobileEvent
    private let reqProfileUpdate = Constants.RequestName.profileUpdate
    private let reqUnsuspend = Constants.RequestName.unsuspend
    private let reqStatus = Constants.RequestName.status
    private let reqUnknown = "unknown/op"

    private let anyType = "delivery"
    private let anyName = "test_event"
    private let http4xx = 400
    private let http5xx = 503

    private func expectBaseFragments(
        in message: String,
        request: String,
        http: Int,
        error: Int = 0,
        errorText: String = ""
    ) {
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

    /// test_3: Suspend request with 5xx error returns mapped 5xx code and base message
    func test_3_errorPair_suspend_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSuspend, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 531)
        expectBaseFragments(in: msg, request: reqSuspend, http: http5xx)
    }

    /// test_4: Suspend request with 4xx error returns mapped 4xx code and base message
    func test_4_errorPair_suspend_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqSuspend, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 431)
        expectBaseFragments(in: msg, request: reqSuspend, http: http4xx)
    }

    /// test_5: Unsubscribe request with 5xx error returns mapped 5xx code and base message
    func test_5_errorPair_unsubscribe_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUnsubscribe, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 532)
        expectBaseFragments(in: msg, request: reqUnsubscribe, http: http5xx)
    }

    /// test_6: Unsubscribe request with 4xx error returns mapped 4xx code and base message
    func test_6_errorPair_unsubscribe_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUnsubscribe, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 432)
        expectBaseFragments(in: msg, request: reqUnsubscribe, http: http4xx)
    }

    /// test_7: Update request with 5xx error returns mapped 5xx code and base message
    func test_7_errorPair_update_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 533)
        expectBaseFragments(in: msg, request: reqUpdate, http: http5xx)
    }

    /// test_8: Update request with 4xx error returns mapped 4xx code and base message
    func test_8_errorPair_update_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqUpdate, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 433)
        expectBaseFragments(in: msg, request: reqUpdate, http: http4xx)
    }

    /// test_9: Push event request with 5xx error returns mapped 5xx code and includes event type in message
    func test_9_errorPair_pushEvent_5xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http5xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 536)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http5xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// test_10: Push event request with 4xx error returns mapped 4xx code and includes event type in message
    func test_10_errorPair_pushEvent_4xx_includesTypeInMessage() {
        let (code, msg) = createErrorPair(requestName: reqPushEvent, code: http4xx, response: nil, type: anyType, name: nil)
        XCTAssertEqual(code, 436)
        expectBaseFragments(in: msg, request: reqPushEvent, http: http4xx)
        XCTAssertTrue(msg.contains("type: \(anyType)"))
    }

    /// test_11: Mobile event request with 5xx error returns mapped 5xx code and includes event name in message
    func test_11_errorPair_mobileEvent_5xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http5xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 537)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http5xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// test_12: Mobile event request with 4xx error returns mapped 4xx code and includes event name in message
    func test_12_errorPair_mobileEvent_4xx_includesNameInMessage() {
        let (code, msg) = createErrorPair(requestName: reqMobileEvent, code: http4xx, response: nil, type: nil, name: anyName)
        XCTAssertEqual(code, 437)
        expectBaseFragments(in: msg, request: reqMobileEvent, http: http4xx)
        XCTAssertTrue(msg.contains("name: \(anyName)"))
    }

    /// test_13: Unsuspend request with any error returns fixed code and base message
    func test_13_errorPair_unsuspend_returns434() {
        let (code, msg) = createErrorPair(requestName: reqUnsuspend, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 434)
        expectBaseFragments(in: msg, request: reqUnsuspend, http: http5xx)
    }

    /// test_14: Status request with any error returns fixed code and base message
    func test_14_errorPair_status_returns435() {
        let (code, msg) = createErrorPair(requestName: reqStatus, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 435)
        expectBaseFragments(in: msg, request: reqStatus, http: http4xx)
    }

    /// test_15: Unknown request with 5xx error returns 539 code and unknown request prefix in message
    func test_15_errorPair_unknown_5xx_returns539WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 539)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http5xx)
    }

    /// test_16: Unknown request with 4xx error returns 439 code and unknown request prefix in message
    func test_16_errorPair_unknown_4xx_returns439WithUnknownPrefix() {
        let (code, msg) = createErrorPair(requestName: reqUnknown, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 439)
        XCTAssertTrue(msg.hasPrefix("unknown request:"))
        expectBaseFragments(in: msg, request: reqUnknown, http: http4xx)
    }

    /// test_17: Success pair for known requests returns appropriate success codes and messages
    func test_17_successPair_allKnownRequests() {
        let s1 = createSuccessPair(requestName: reqSubscribe, type: nil, name: nil)
        XCTAssertEqual(s1.0, 230)
        XCTAssertEqual(s1.1, Constants.SDKSuccessMessage.subscribeSuccess)

        let s2 = createSuccessPair(requestName: reqSuspend, type: nil, name: nil)
        XCTAssertEqual(s2.0, 231)
        XCTAssertEqual(s2.1, Constants.SDKSuccessMessage.suspendSuccess)

        let s3 = createSuccessPair(requestName: reqUnsubscribe, type: nil, name: nil)
        XCTAssertEqual(s3.0, 232)
        XCTAssertEqual(s3.1, Constants.SDKSuccessMessage.unsubscribeSuccess)

        let s4 = createSuccessPair(requestName: reqUpdate, type: nil, name: nil)
        XCTAssertEqual(s4.0, 233)
        XCTAssertEqual(s4.1, Constants.SDKSuccessMessage.tokenUpdateSuccess)

        let s5 = createSuccessPair(requestName: reqUnsuspend, type: nil, name: nil)
        XCTAssertEqual(s5.0, 234)
        XCTAssertEqual(s5.1, Constants.SDKSuccessMessage.pushUnSuspendSuccess)

        let s6 = createSuccessPair(requestName: reqStatus, type: nil, name: nil)
        XCTAssertEqual(s6.0, 235)
        XCTAssertEqual(s6.1, Constants.SDKSuccessMessage.statusSuccess)

        let s7 = createSuccessPair(requestName: reqProfileUpdate, type: nil, name: nil)
        XCTAssertEqual(s7.0, 238)
        XCTAssertEqual(s7.1, Constants.SDKSuccessMessage.profileUpdateSuccess)
    }

    /// test_18: Push event success returns success code and message with appended event type
    func test_18_successPair_pushEvent_appendsType() {
        let result = createSuccessPair(requestName: reqPushEvent, type: anyType, name: nil)
        XCTAssertEqual(result.0, 236)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.pushEventDelivered + anyType)
    }

    /// test_19: Mobile event success returns success code and message with appended event name
    func test_19_successPair_mobileEvent_appendsName() {
        let result = createSuccessPair(requestName: reqMobileEvent, type: nil, name: anyName)
        XCTAssertEqual(result.0, 237)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.mobileEventDelivered + anyName)
    }

    /// test_20: Unknown request success returns zero code and unknown request message
    func test_20_successPair_unknown_returnsZeroAndUnknownRequest() {
        let result = createSuccessPair(requestName: reqUnknown, type: nil, name: nil)
        XCTAssertEqual(result.0, 0)
        XCTAssertEqual(result.1, "unknown request")
    }

    /// test_21: getRequestMessages returns both error and success pairs consistent with builders
    func test_21_getRequestMessages_returnsBothPairs() {
        let res = Response(error: 12, errorText: "bad", profile: nil)
        let m = getRequestMessages(requestName: reqPushEvent, code: http5xx, response: res, type: anyType, name: nil)

        XCTAssertEqual(m.error.0, 536)
        expectBaseFragments(in: m.error.1, request: reqPushEvent, http: http5xx, error: 12, errorText: "bad")
        XCTAssertTrue(m.error.1.contains("type: \(anyType)"))

        XCTAssertEqual(m.success.0, 236)
        XCTAssertEqual(m.success.1, Constants.SDKSuccessMessage.pushEventDelivered + anyType)
    }
    
    /// test_22: Profile update request with 5xx error returns mapped 5xx code and base message
    func test_22_errorPair_profileUpdate_5xx_usesMapped5xxCode() {
        let (code, msg) = createErrorPair(requestName: reqProfileUpdate, code: http5xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 538)
        expectBaseFragments(in: msg, request: reqProfileUpdate, http: http5xx)
    }

    /// test_23: Profile update request with 4xx error returns mapped 4xx code and base message
    func test_23_errorPair_profileUpdate_4xx_usesMapped4xxCode() {
        let (code, msg) = createErrorPair(requestName: reqProfileUpdate, code: http4xx, response: nil, type: nil, name: nil)
        XCTAssertEqual(code, 438)
        expectBaseFragments(in: msg, request: reqProfileUpdate, http: http4xx)
    }

    /// test_24: Success pair for profile update returns code and message
    func test_24_successPair_profileUpdate_returns238() {
        let result = createSuccessPair(requestName: reqProfileUpdate, type: nil, name: nil)
        XCTAssertEqual(result.0, 238)
        XCTAssertEqual(result.1, Constants.SDKSuccessMessage.profileUpdateSuccess)
    }

    /// test_25: getRequestMessages for mobile event returns both error and success
    func test_25_getRequestMessages_mobileEvent_returnsBothPairs() {
        let res = Response(error: 7, errorText: "oops", profile: nil)
        let m = getRequestMessages(requestName: reqMobileEvent, code: http4xx, response: res, type: nil, name: anyName)

        XCTAssertEqual(m.error.0, 437)
        expectBaseFragments(in: m.error.1, request: reqMobileEvent, http: http4xx, error: 7, errorText: "oops")
        XCTAssertTrue(m.error.1.contains("name: \(anyName)"))

        XCTAssertEqual(m.success.0, 237)
        XCTAssertEqual(m.success.1, Constants.SDKSuccessMessage.mobileEventDelivered + anyName)
    }

    /// test_26: getRequestMessages for profile update returns both error and success
    func test_26_getRequestMessages_profileUpdate_returnsBothPairs() {
        let res = Response(error: 9, errorText: "bad profile", profile: nil)
        let m = getRequestMessages(requestName: reqProfileUpdate, code: http5xx, response: res, type: nil, name: nil)

        XCTAssertEqual(m.error.0, 538)
        expectBaseFragments(in: m.error.1, request: reqProfileUpdate, http: http5xx, error: 9, errorText: "bad profile")

        XCTAssertEqual(m.success.0, 238)
        XCTAssertEqual(m.success.1, Constants.SDKSuccessMessage.profileUpdateSuccess)
    }
}

