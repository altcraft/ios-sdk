//
//  ExtensionTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * ExtensionsTests
 *
 * Positive scenarios:
 *  - test_1: Data base64 URL encoded with valid string successfully decodes to original data.
 *  - test_2: Data base64 URL encoded with missing padding correctly handles and decodes the string.
 *  - test_3: Array string ts_append with mixed values adds all elements including nil values.
 *  - test_4: Array string ts_last on non-empty array returns the most recently added element.
 *  - test_5: Array string ts_removeAll clears all elements from the array.
 *
 * Edge scenarios:
 *  - test_6: Data base64 URL encoded with invalid string returns nil.
 *  - test_7: Array string ts_last on empty array returns nil.
 */
final class ExtensionsTests: XCTestCase {

    /// test_1: Data base64 URL encoded with valid string successfully decodes to original data
    func test_1_base64UrlEncoded_decodesValid() {
        let original = "hello"
        let base64 = Data(original.utf8).base64EncodedString()
        let base64url = base64.replacingOccurrences(of: "+", with: "-")
                              .replacingOccurrences(of: "/", with: "_")
                              .replacingOccurrences(of: "=", with: "")
        let decoded = Data(base64UrlEncoded: base64url)
        XCTAssertEqual(decoded, Data(original.utf8))
    }

    /// test_2: Data base64 URL encoded with missing padding correctly handles and decodes the string
    func test_2_base64UrlEncoded_handlesMissingPadding() {
        let base64url = "aGVsbG8"
        let decoded = Data(base64UrlEncoded: base64url)
        XCTAssertEqual(decoded.flatMap { String(data: $0, encoding: .utf8) }, "hello")
    }

    /// test_6: Data base64 URL encoded with invalid string returns nil
    func test_6_base64UrlEncoded_returnsNilForInvalid() {
        let invalid = "%%%@@@"
        XCTAssertNil(Data(base64UrlEncoded: invalid))
    }

    /// test_3: Array string ts_append with mixed values adds all elements including nil values
    func test_3_tsAppend_addsElements() {
        var arr: [String?] = []
        arr.ts_append("first")
        arr.ts_append(nil)
        XCTAssertEqual(arr.count, 2)
        XCTAssertEqual(arr[0], "first")
        XCTAssertNil(arr[1])
    }

    /// test_4: Array string ts_last on non-empty array returns the most recently added element
    func test_4_tsLast_returnsLastElement() {
        var arr: [String?] = []
        arr.ts_append("a")
        arr.ts_append("b")
        XCTAssertEqual(arr.ts_last()!, "b")
    }

    /// test_5: Array string ts_removeAll clears all elements from the array
    func test_5_tsRemoveAll_clearsArray() {
        var arr: [String?] = ["x", "y"]
        arr.ts_removeAll()
        XCTAssertTrue(arr.isEmpty)
    }

    /// test_7: Array string ts_last on empty array returns nil
    func test_7_tsLast_onEmptyReturnsNil() {
        let arr: [String?] = []
        let last: String? = arr.ts_last() ?? nil
        XCTAssertNil(last)
    }
}
