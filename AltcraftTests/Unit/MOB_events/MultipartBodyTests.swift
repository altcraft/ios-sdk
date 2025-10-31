//
//  MultipartBodyTest.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * MultipartBodyTest
 *
 * Positive scenarios:
 *  - test_1: makeBoundary → generates unique values with "Boundary-" prefix.
 *  - test_2: Content-Disposition without filename → creates header with name only.
 *  - test_3: Content-Disposition with filename → creates header with name and filename.
 *  - test_4: buildMultipartBody with single part → creates correct structure with boundary and content.
 *  - test_5: buildMultipartBody with multiple parts → correctly combines all parts with boundaries.
 *  - test_6: buildMultipartBody with empty parts → creates only closing boundary.
 *  - test_7: buildMultipartBody with file data → correctly handles filename and mime-type.
 *  - test_8: Complete multipart flow → generates boundary and builds proper multipart structure.
 *
 * Edge scenarios:
 *  - test_3b: Content-Disposition with empty filename → treats as no filename.
 */
final class MultipartBodyTest: XCTestCase {
    
    private func makeContentDisposition(_ name: String, filename: String?) -> Data {
        if let filename, !filename.isEmpty {
            return Data("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8)
        } else {
            return Data("Content-Disposition: form-data; name=\"\(name)\"\r\n".utf8)
        }
    }
    
    private struct TestPart {
        let name: String
        let filename: String?
        let mime: String
        let data: Data
        
        init(name: String, filename: String? = nil, mime: String, data: Data) {
            self.name = name
            self.filename = filename
            self.mime = mime
            self.data = data
        }
    }
    
    /// test_1: makeBoundary generates unique values with "Boundary-" prefix
    func test_1_makeBoundary_generatesUniqueValues() {
        let boundary1 = makeBoundary()
        let boundary2 = makeBoundary()
        let boundary3 = makeBoundary()
        
        XCTAssertTrue(boundary1.hasPrefix("Boundary-"))
        XCTAssertTrue(boundary2.hasPrefix("Boundary-"))
        XCTAssertTrue(boundary3.hasPrefix("Boundary-"))
        
        let boundaries = [boundary1, boundary2, boundary3]
        let uniqueBoundaries = Set(boundaries)
        XCTAssertEqual(boundaries.count, uniqueBoundaries.count)
    }
    
    /// test_2: Content-Disposition without filename creates header with name only
    func test_2_contentDisposition_withoutFilename() {
        let result = makeContentDisposition("username", filename: nil)
        let expected = "Content-Disposition: form-data; name=\"username\"\r\n"
        
        XCTAssertEqual(String(data: result, encoding: .utf8), expected)
    }
    
    /// test_3: Content-Disposition with filename creates header with name and filename
    func test_3_contentDisposition_withFilename() {
        let result = makeContentDisposition("avatar", filename: "photo.jpg")
        let expected = "Content-Disposition: form-data; name=\"avatar\"; filename=\"photo.jpg\"\r\n"
        
        XCTAssertEqual(String(data: result, encoding: .utf8), expected)
    }
    
    /// test_3b: Content-Disposition with empty filename treats as no filename
    func test_3b_contentDisposition_withEmptyFilename() {
        let result = makeContentDisposition("document", filename: "")
        let expected = "Content-Disposition: form-data; name=\"document\"\r\n"
        
        XCTAssertEqual(String(data: result, encoding: .utf8), expected)
    }
    
    /// test_4: buildMultipartBody with single part creates correct structure with boundary and content
    func test_4_buildMultipartBody_singlePart() {
        let boundary = "test-boundary"
        let parts = [
            TestPart(name: "field1", filename: nil, mime: "text/plain", data: Data("test value".utf8))
        ]
        
        let result = buildMultipartBody(parts: convertTestParts(parts), boundary: boundary)
        let resultString = String(data: result, encoding: .utf8)!
        
        XCTAssertTrue(resultString.contains("--test-boundary\r\n"))
        XCTAssertTrue(resultString.contains("Content-Disposition: form-data; name=\"field1\"\r\n"))
        XCTAssertTrue(resultString.contains("Content-Type: text/plain\r\n\r\n"))
        XCTAssertTrue(resultString.contains("test value"))
        XCTAssertTrue(resultString.hasSuffix("--test-boundary--\r\n"))
    }
    
    /// test_5: buildMultipartBody with multiple parts correctly combines all parts with boundaries
    func test_5_buildMultipartBody_multipleParts() {
        let boundary = "test-boundary"
        let parts = [
            TestPart(name: "text", filename: nil, mime: "text/plain", data: Data("hello".utf8)),
            TestPart(name: "number", filename: nil, mime: "text/plain", data: Data("42".utf8))
        ]
        
        let result = buildMultipartBody(parts: convertTestParts(parts), boundary: boundary)
        let resultString = String(data: result, encoding: .utf8)!
        
        XCTAssertTrue(resultString.contains("name=\"text\""))
        XCTAssertTrue(resultString.contains("hello"))
        XCTAssertTrue(resultString.contains("name=\"number\""))
        XCTAssertTrue(resultString.contains("42"))
        
        let boundaryCount = resultString.components(separatedBy: "--test-boundary").count - 1
        XCTAssertEqual(boundaryCount, 3)
    }
    
    /// test_6: buildMultipartBody with empty parts creates only closing boundary
    func test_6_buildMultipartBody_emptyParts() {
        let boundary = "test-boundary"
        let result = buildMultipartBody(parts: [], boundary: boundary)
        let expected = Data("--test-boundary--\r\n".utf8)
        
        XCTAssertEqual(result, expected)
    }
    
    /// test_7: buildMultipartBody with file data correctly handles filename and mime-type
    func test_7_buildMultipartBody_withFileData() {
        let boundary = "test-boundary"
        let jsonData = Data("{\"key\": \"value\"}".utf8)
        let parts = [
            TestPart(name: "jsonFile", filename: "data.json", mime: "application/json", data: jsonData)
        ]
        
        let result = buildMultipartBody(parts: convertTestParts(parts), boundary: boundary)
        let resultString = String(data: result, encoding: .utf8)!
        
        XCTAssertTrue(resultString.contains("name=\"jsonFile\"; filename=\"data.json\""))
        XCTAssertTrue(resultString.contains("Content-Type: application/json"))
        XCTAssertTrue(resultString.contains("{\"key\": \"value\"}"))
    }
    
    /// test_8: Complete multipart flow generates boundary and builds proper multipart structure
    func test_8_integration_completeMultipartFlow() {
        let boundary = makeBoundary()
        
        let parts = [
            TestPart(name: "textField", filename: nil, mime: "text/plain", data: Data("sample text".utf8)),
            TestPart(name: "file", filename: "document.pdf", mime: "application/pdf", data: Data("pdf content".utf8))
        ]
        
        let body = buildMultipartBody(parts: convertTestParts(parts), boundary: boundary)
        let bodyString = String(data: body, encoding: .utf8)!
        
        XCTAssertTrue(bodyString.hasPrefix("--\(boundary)\r\n"))
        XCTAssertTrue(bodyString.hasSuffix("--\(boundary)--\r\n"))
        
        XCTAssertTrue(bodyString.contains("name=\"textField\""))
        XCTAssertTrue(bodyString.contains("sample text"))
        XCTAssertTrue(bodyString.contains("name=\"file\"; filename=\"document.pdf\""))
        XCTAssertTrue(bodyString.contains("Content-Type: application/pdf"))
        XCTAssertTrue(bodyString.contains("pdf content"))
        
        XCTAssertEqual(parts[0].data, Data("sample text".utf8))
        XCTAssertEqual(parts[1].data, Data("pdf content".utf8))
    }
    
    private func convertTestParts(_ testParts: [TestPart]) -> [Part] {
        return testParts.map { testPart in
            Part(
                name: testPart.name,
                data: testPart.data,
                mime: testPart.mime,
                filename: testPart.filename
            )
        }
    }
}
