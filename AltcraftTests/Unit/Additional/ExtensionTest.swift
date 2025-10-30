//
//  ExtensionTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ExtensionsTest
 *
 * Positive scenarios:
 *  - test_1: Data(base64UrlEncoded:) with valid Base64URL string → successfully decodes to original data.
 *  - test_2: Data(base64UrlEncoded:) with missing padding → correctly handles and decodes the string.
 *  - test_3: Array<String?>.ts_append with mixed values → adds all elements including nil values.
 *  - test_4: Array<String?>.ts_last on non-empty array → returns the most recently added element.
 *  - test_5: Array<String?>.ts_removeAll → clears all elements from the array.
 *
 * Edge scenarios:
 *  - test_6: Data(base64UrlEncoded:) with invalid string → returns nil.
 *  - test_7: Array<String?>.ts_last on empty array → returns nil.
 */
final class ExtensionsTest: XCTestCase {

    /// test_1: decodes a valid Base64URL string
    func test_1_base64UrlEncoded_decodesValid() {
        let original = "hello"
        let base64 = Data(original.utf8).base64EncodedString()
        let base64url = base64.replacingOccurrences(of: "+", with: "-")
                              .replacingOccurrences(of: "/", with: "_")
                              .replacingOccurrences(of: "=", with: "")
        let decoded = Data(base64UrlEncoded: base64url)
        XCTAssertEqual(decoded, Data(original.utf8))
    }

    /// test_2: handles missing padding correctly
    func test_2_base64UrlEncoded_handlesMissingPadding() {
        let base64url = "aGVsbG8"
        let decoded = Data(base64UrlEncoded: base64url)
        XCTAssertEqual(decoded.flatMap { String(data: $0, encoding: .utf8) }, "hello")
    }

    /// test_6: returns nil for invalid input
    func test_6_base64UrlEncoded_returnsNilForInvalid() {
        let invalid = "%%%@@@"
        XCTAssertNil(Data(base64UrlEncoded: invalid))
    }

    /// test_3: ts_append adds elements including nil
    func test_3_tsAppend_addsElements() {
        var arr: [String?] = []
        arr.ts_append("first")
        arr.ts_append(nil)
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0], "first")
        XCTAssertNil(arr[1])
    }

    /// test_4: ts_last returns the last element
    func test_4_tsLast_returnsLastElement() {
        var arr: [String?] = []
        arr.ts_append("a")
        arr.ts_append("b")
        XCTAssertEqual(arr.ts_last()!, "b")
    }

    /// test_5: ts_removeAll clears the array
    func test_5_tsRemoveAll_clearsArray() {
        var arr: [String?] = ["x", "y"]
        arr.ts_removeAll()
        XCTAssertTrue(arr.isEmpty)
    }

    /// test_7: ts_last returns nil when array is empty
    func test_7_tsLast_onEmptyReturnsNil() {
        let arr: [String?] = []
        let last: String? = arr.ts_last() ?? nil
        XCTAssertNil(last)
    }
}

