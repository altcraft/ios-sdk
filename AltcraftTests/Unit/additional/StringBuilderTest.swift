//
//  CreateMessageTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * StringBuilderTest
 *
 * Positive scenarios:
 *  - test_1: formatFunctionName collapses single param to "()".
 *  - test_2: formatFunctionName collapses multiple params to "()".
 *  - test_3: formatFunctionName keeps names without parens unchanged.
 *  - test_4: subscribeURL builds expected endpoint.
 *  - test_5: updateUrl builds expected endpoint.
 *  - test_6: unSuspendUrl builds expected endpoint.
 *  - test_7: profileUrl builds expected endpoint.
 *  - test_8: pushEventURL appends event type to "/event/push/<type>".
 *  - test_9: matchingAsString returns valid JSON with expected keys/values.
 *
 * Notes:
 *  - Core Data object for pushEventURL is created in-memory via TestCoreDataStack.
 *  - JSON output from matchingAsString is validated by decoding into a dictionary.
 */
final class StringBuilderTest: XCTestCase {

    // ---------- Test inputs ----------
    private let baseURL = "https://pxl.altcraft.com"
    private let fnWithParams = "pushSubscribe(message: String)"
    private let fnWithMultiParams = "fn(arg1: Int, arg2: String)"
    private let fnNoParams = "simpleFn"

    // ---------- Expected full strings ----------
    private let expectFnWithParams = "pushSubscribe()"
    private let expectFnWithMultiParams = "fn()"
    private let expectFnNoChange = "simpleFn"

    private let expectSubscribe = "https://pxl.altcraft.com/subscription/push/subscribe/"
    private let expectUpdate    = "https://pxl.altcraft.com/subscription/push/update/"
    private let expectUnsuspend = "https://pxl.altcraft.com/subscription/push/unsuspend/"
    private let expectProfile   = "https://pxl.altcraft.com/subscription/push/status/"

    // ---------- Assertion messages ----------
    private let msgExactMatch     = "Result string must match expected value"
    private let msgJsonDecodable  = "Returned string must be valid JSON"
    private let msgJsonKeyMissing = "JSON must contain required key"
    private let msgJsonValueWrong = "JSON value is unexpected"

    // Core Data test stack for pushEventURL
    private var coreData: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        // Use real model & bundle identifier as in production
        coreData = TestCoreDataStack(
            modelName: Constants.CoreData.modelName,
            bundleToken: AltcraftPushReceiver.self,
            bundleIdentifier: Constants.CoreData.identifier
        )
    }

    override func tearDown() {
        coreData = nil
        super.tearDown()
    }

    // ---------------------------
    // formatFunctionName
    // ---------------------------

    /// test_1: collapses single param to "()"
    func test_1_formatFunctionName_collapsesSingleParam() {
        let actual = formatFunctionName(fnWithParams)
        XCTAssertEqual(actual, expectFnWithParams, msgExactMatch)
    }

    /// test_2: collapses multiple params to "()"
    func test_2_formatFunctionName_collapsesMultiParam() {
        let actual = formatFunctionName(fnWithMultiParams)
        XCTAssertEqual(actual, expectFnWithMultiParams, msgExactMatch)
    }

    /// test_3: keeps names without parens unchanged
    func test_3_formatFunctionName_keepsNameWithoutParens() {
        let actual = formatFunctionName(fnNoParams)
        XCTAssertEqual(actual, expectFnNoChange, msgExactMatch)
    }

    // ---------------------------
    // subscribe / update / unsuspend / profile
    // ---------------------------

    /// test_4: subscribeURL builds expected endpoint
    func test_4_subscribeURL_buildsExpectedEndpoint() {
        XCTAssertEqual(subscribeURL(baseURL), expectSubscribe, msgExactMatch)
    }

    /// test_5: updateUrl builds expected endpoint
    func test_5_updateUrl_buildsExpectedEndpoint() {
        XCTAssertEqual(updateUrl(baseURL), expectUpdate, msgExactMatch)
    }

    /// test_6: unSuspendUrl builds expected endpoint
    func test_6_unSuspendUrl_buildsExpectedEndpoint() {
        XCTAssertEqual(unSuspendUrl(baseURL), expectUnsuspend, msgExactMatch)
    }

    /// test_7: profileUrl builds expected endpoint
    func test_7_profileUrl_buildsExpectedEndpoint() {
        XCTAssertEqual(profileUrl(baseURL), expectProfile, msgExactMatch)
    }

    // ---------------------------
    // pushEventURL
    // ---------------------------

    /// test_8: appends event type to "/event/push/<type>"
    func test_8_pushEventURL_appendsEventType() throws {
        let ctx = coreData.viewContext
        let obj = NSEntityDescription.insertNewObject(forEntityName: "PushEventEntity", into: ctx)
        obj.setValue("delivery", forKey: "type")
        let url = eventPushURL(baseURL, event: obj as! PushEventEntity)
        XCTAssertEqual(url, "\(baseURL)/event/push/delivery", msgExactMatch)
    }

    // ---------------------------
    // matchingAsString
    // ---------------------------

    /// test_9: returns valid JSON with expected keys/values
    func test_9_matchingAsString_returnsValidJsonAndPairs() throws {
        let dbId = 42
        let matching = "email"
        let value = "user@example.com"

        let jsonString = matchingAsString(dbId: dbId, matching: matching, value: value)

        guard let data = jsonString.data(using: .utf8) else {
            XCTFail(msgJsonDecodable); return
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(obj, msgJsonDecodable)

        let kDbId       = Constants.AuthKeys.dbId
        let kMatching   = Constants.AuthKeys.matching
        let kMatchingID = Constants.AuthKeys.matchingID

        XCTAssertNotNil(obj?[kDbId], msgJsonKeyMissing)
        XCTAssertNotNil(obj?[kMatching], msgJsonKeyMissing)
        XCTAssertNotNil(obj?[kMatchingID], msgJsonKeyMissing)

        XCTAssertEqual(obj?[kDbId] as? String, "\(dbId)", msgJsonValueWrong)
        XCTAssertEqual(obj?[kMatching] as? String, matching, msgJsonValueWrong)
        XCTAssertEqual(obj?[kMatchingID] as? String, value, msgJsonValueWrong)
    }
}
