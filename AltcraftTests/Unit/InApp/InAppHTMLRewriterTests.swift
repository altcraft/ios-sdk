//
//  InAppHTMLRewriterTests.swift
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
 * InAppHTMLRewriterTests
 *
 * Positive scenarios:
 *  - test_1: rewriteImageURLs replaces single image URL in HTML.
 *  - test_2: rewriteImageURLs replaces multiple image URLs in HTML.
 *  - test_3: makeCustomSchemeURL converts https URL to acimg scheme.
 *  - test_4: makeCustomSchemeURL converts http URL to acimg scheme.
 *  - test_5: rewriteImageURLs leaves HTML unchanged when imageURLs is empty.
 *  - test_6: rewriteImageURLs replaces all occurrences of the same URL.
 *
 * Edge scenarios:
 *  - test_7: makeCustomSchemeURL returns original for invalid URL string.
 *  - test_8: makeCustomSchemeURL returns original for URL without scheme.
 *  - test_9: rewriteImageURLs does not replace partial substring match.
 */
final class InAppHTMLRewriterTests: IsolatedTestCase {

    /// test_1: rewriteImageURLs replaces single image URL in HTML
    func test_1_rewriteImageURLs_replacesSingleImageURL() {
        let html = "<img src=\"https://example.com/img.png\">"
        let urls = ["https://example.com/img.png"]
        let result = InAppHTMLRewriter.rewriteImageURLs(in: html, imageURLs: urls)
        XCTAssertEqual(result, "<img src=\"acimg://https/example.com/img.png\">")
    }

    /// test_2: rewriteImageURLs replaces multiple image URLs in HTML
    func test_2_rewriteImageURLs_replacesMultipleImageURLs() {
        let html = """
        <img src="https://a.com/1.png">
        <img src="https://b.com/2.jpg">
        """
        let urls = ["https://a.com/1.png", "https://b.com/2.jpg"]
        let result = InAppHTMLRewriter.rewriteImageURLs(in: html, imageURLs: urls)
        XCTAssertTrue(result.contains("acimg://https/a.com/1.png"))
        XCTAssertTrue(result.contains("acimg://https/b.com/2.jpg"))
        XCTAssertFalse(result.contains("https://a.com/1.png"))
        XCTAssertFalse(result.contains("https://b.com/2.jpg"))
    }

    /// test_3: makeCustomSchemeURL converts https URL to acimg scheme
    func test_3_makeCustomSchemeURL_httpsToAcimg() {
        let result = InAppHTMLRewriter.makeCustomSchemeURL(from: "https://example.com/path/image.png")
        XCTAssertEqual(result, "acimg://https/example.com/path/image.png")
    }

    /// test_4: makeCustomSchemeURL converts http URL to acimg scheme
    func test_4_makeCustomSchemeURL_httpToAcimg() {
        let result = InAppHTMLRewriter.makeCustomSchemeURL(from: "http://example.com/img.png")
        XCTAssertEqual(result, "acimg://http/example.com/img.png")
    }

    /// test_5: rewriteImageURLs leaves HTML unchanged when imageURLs is empty
    func test_5_rewriteImageURLs_unchangedWhenNoURLs() {
        let html = "<img src=\"https://example.com/img.png\">"
        let result = InAppHTMLRewriter.rewriteImageURLs(in: html, imageURLs: [])
        XCTAssertEqual(result, html)
    }

    /// test_6: rewriteImageURLs replaces all occurrences of the same URL
    func test_6_rewriteImageURLs_replacesAllOccurrences() {
        let html = """
        <img src="https://example.com/img.png">
        <a href="https://example.com/img.png"><img src="https://example.com/img.png"></a>
        """
        let urls = ["https://example.com/img.png"]
        let result = InAppHTMLRewriter.rewriteImageURLs(in: html, imageURLs: urls)
        XCTAssertFalse(result.contains("https://example.com/img.png"))
        let count = result.components(separatedBy: "acimg://https/example.com/img.png").count - 1
        XCTAssertEqual(count, 3)
    }

    /// test_7: makeCustomSchemeURL returns original for invalid URL string
    func test_7_makeCustomSchemeURL_returnsOriginal_forInvalidURL() {
        let result = InAppHTMLRewriter.makeCustomSchemeURL(from: "not a url at all!!!")
        XCTAssertEqual(result, "not a url at all!!!")
    }

    /// test_8: makeCustomSchemeURL returns original for URL without scheme
    func test_8_makeCustomSchemeURL_returnsOriginal_forNoScheme() {
        let result = InAppHTMLRewriter.makeCustomSchemeURL(from: "example.com/img.png")
        XCTAssertEqual(result, "example.com/img.png")
    }

    /// test_9: rewriteImageURLs replaces exact string match (not partial)
    func test_9_rewriteImageURLs_exactStringMatch() {
        let html = "<img src=\"https://example.com/img.png?v=1\">"
        let urls = ["https://example.com/img.png"]
        let result = InAppHTMLRewriter.rewriteImageURLs(in: html, imageURLs: urls)
        XCTAssertTrue(result.contains("acimg://https/example.com/img.png?v=1"))
    }
}
