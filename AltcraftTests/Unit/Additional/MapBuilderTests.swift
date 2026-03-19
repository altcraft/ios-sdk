//
//  MapBuilderTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * MapBuilderTests
 *
 * Positive scenarios:
 *  - test_1: mapValue with all parameters → includes uid, type, name and wraps http code/response in ResponseWithHttp.
 *  - test_2: mapValue with no parameters → omits uid/type/name but still includes ResponseWithHttp wrapper with nil values.
 */

final class MapBuilderTests: IsolatedTestCase {

    private let inputUid = "u-123"
    private let inputType = "delivery"
    private let inputName = "test_event"
    private let httpCodeOK = 200

    private let keyA = "a"
    private let keyB = "b"
    private let keyC = "c"
    private let keyK = "k"
    private let keyX = "x"
    private let keyY = "y"

    /// test_1: mapValue with all parameters includes uid, type, name and wraps http code/response in ResponseWithHttp
    func test_1_mapValue_includesUidTypeAndResponseWrapper() {
        let response: Response? = nil

        let map = mapValue(
            code: httpCodeOK,
            response: response,
            uid: inputUid,
            type: inputType,
            name: inputName
        )

        XCTAssertEqual(map[Constants.MapKeys.uid] as? String, inputUid)
        XCTAssertEqual(map[Constants.MapKeys.type] as? String, inputType)
        XCTAssertEqual(map[Constants.MapKeys.name] as? String, inputName)

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper missing")
            return
        }
        XCTAssertEqual(wrapped.httpCode, httpCodeOK)
        XCTAssertNil(wrapped.response)
    }

    /// test_2: mapValue with no parameters omits uid/type/name but still includes ResponseWithHttp wrapper with nil values
    func test_2_mapValue_omitsMissingKeys_butIncludesWrapper() {
        let map = mapValue()

        XCTAssertNil(map[Constants.MapKeys.uid])
        XCTAssertNil(map[Constants.MapKeys.type])
        XCTAssertNil(map[Constants.MapKeys.name])

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper must be present")
            return
        }
        XCTAssertNil(wrapped.httpCode)
        XCTAssertNil(wrapped.response)
    }

    /// test_3: mapValue with only name parameter includes name in map and omits other optional fields
    func test_3_mapValue_includesNameWhenProvided() {
        let map = mapValue(name: inputName)

        XCTAssertEqual(map[Constants.MapKeys.name] as? String, inputName)
        XCTAssertNil(map[Constants.MapKeys.uid])
        XCTAssertNil(map[Constants.MapKeys.type])

        guard let wrapped = map[Constants.MapKeys.responseWithHttp] as? ResponseWithHttp else {
            XCTFail("responseWithHttp wrapper must be present")
            return
        }
        XCTAssertNil(wrapped.httpCode)
        XCTAssertNil(wrapped.response)
    }
}
