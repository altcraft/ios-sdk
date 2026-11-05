//
//  PresenterTests.swift
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
 * PresenterTests
 *
 * Positive scenarios:
 * - test_1: InAppContent decodes valid content with images.
 * - test_2: InAppContent decodes empty images list.
 * - test_3: InAppContent decodes with displayType field.
 *
 * Edge scenarios:
 * - test_4: InAppContent decoding fails for invalid JSON.
 * - test_5: InAppContent decoding fails when display_type is missing.
 */
final class PresenterTests: XCTestCase {

    private func jsonData(
        content: String,
        images: [String],
        displayType: String = "fullscreen"
    ) throws -> Data {
        let json: [String: Any] = [
            "content": content,
            "images_links": images,
            "display_type": displayType
        ]
        return try JSONSerialization.data(withJSONObject: json, options: [])
    }

    /// test_1: InAppContent JSON decoding works for valid content with images
    func test_1_InAppContent_decodes_valid_content_with_images() throws {
        let json = try jsonData(content: "<html>hello</html>", images: ["https://a.com/1.png", "https://a.com/2.png"])
        let decoded = try JSONDecoder().decode(InAppModel.InAppContent.self, from: json)
        XCTAssertEqual(decoded.content, "<html>hello</html>")
        XCTAssertEqual(decoded.images, ["https://a.com/1.png", "https://a.com/2.png"])
        XCTAssertEqual(decoded.displayType, "fullscreen")
    }

    /// test_2: InAppContent JSON decoding works for empty images list
    func test_2_InAppContent_decodes_empty_images_list() throws {
        let json = try jsonData(content: "{\"title\":\"json in-app\"}", images: [])
        let decoded = try JSONDecoder().decode(InAppModel.InAppContent.self, from: json)
        XCTAssertEqual(decoded.content, "{\"title\":\"json in-app\"}")
        XCTAssertTrue(decoded.images.isEmpty)
    }

    /// test_3: InAppContent decodes with displayType field
    func test_3_InAppContent_decodes_displayType() throws {
        let json = try jsonData(content: "body", images: [], displayType: "modal")
        let decoded = try JSONDecoder().decode(InAppModel.InAppContent.self, from: json)
        XCTAssertEqual(decoded.displayType, "modal")
    }

    /// test_4: InAppContent decoding fails for invalid JSON
    func test_4_InAppContent_decodingFails_forInvalidJSON() throws {
        let invalidData = Data("{invalid-json".utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(InAppModel.InAppContent.self, from: invalidData))
    }

    /// test_5: InAppContent decoding fails when display_type is missing
    func test_5_InAppContent_decodingFails_whenDisplayTypeMissing() throws {
        let json = try JSONSerialization.data(
            withJSONObject: ["content": "body", "images_links": []],
            options: []
        )
        XCTAssertThrowsError(try JSONDecoder().decode(InAppModel.InAppContent.self, from: json))
    }
}
