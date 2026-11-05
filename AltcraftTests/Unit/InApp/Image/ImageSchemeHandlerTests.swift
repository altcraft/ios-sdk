//
//  ImageSchemeHandlerTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import WebKit
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
 * ImageSchemeHandlerTests
 *
 * Positive scenarios:
 * - test_1: scheme equals expected custom image scheme.
 * - test_2: originalURLString restores HTTPS image URL.
 * - test_3: originalURLString restores HTTP image URL with query.
 * - test_4: mimeType returns PNG MIME type.
 * - test_5: mimeType returns WEBP MIME type.
 * - test_6: mimeType returns GIF MIME type.
 * - test_7: mimeType returns SVG MIME type.
 * - test_11: response callbacks are delivered on the main thread.
 *
 * Edge scenarios:
 * - test_8: originalURLString returns nil for wrong scheme.
 * - test_9: mimeType returns JPEG MIME type for unknown extension.
 * - test_10: stop does not crash.
 * - test_12: stop cancels the serving task and skips all callbacks.
 * - test_13: originalURLString preserves percent-encoding (%20) — cache key parity.
 *
 */
@available(iOSApplicationExtension, unavailable)
final class ImageSchemeHandlerTests: IsolatedTestCase {

    /// test_1: scheme equals expected custom image scheme
    func test_1_scheme_equals_expected_custom_image_scheme() {
        XCTAssertEqual(
            ImageSchemeHandler.scheme,
            "acimg"
        )
    }

    /// test_2: originalURLString restores HTTPS image URL
    func test_2_originalURLString_restores_https_image_url() throws {
        let url = try XCTUnwrap(
            URL(string: "acimg://https/example.com/images/picture.png")
        )

        let result = ImageSchemeHandler.test_originalURLString(
            from: url
        )

        XCTAssertEqual(
            result,
            "https://example.com/images/picture.png"
        )
    }

    /// test_3: originalURLString restores HTTP image URL with query
    func test_3_originalURLString_restores_http_image_url_with_query() throws {
        let url = try XCTUnwrap(
            URL(string: "acimg://http/example.com/image.jpg?width=100&height=200")
        )

        let result = ImageSchemeHandler.test_originalURLString(
            from: url
        )

        XCTAssertEqual(
            result,
            "http://example.com/image.jpg?width=100&height=200"
        )
    }

    /// test_4: mimeType returns PNG MIME type
    func test_4_mimeType_returns_png_mime_type() {
        let url = URL(
            fileURLWithPath: "/tmp/image.png"
        )

        XCTAssertEqual(
            ImageSchemeHandler.test_mimeType(for: url),
            "image/png"
        )
    }

    /// test_5: mimeType returns WEBP MIME type
    func test_5_mimeType_returns_webp_mime_type() {
        let url = URL(
            fileURLWithPath: "/tmp/image.webp"
        )

        XCTAssertEqual(
            ImageSchemeHandler.test_mimeType(for: url),
            "image/webp"
        )
    }

    /// test_6: mimeType returns GIF MIME type
    func test_6_mimeType_returns_gif_mime_type() {
        let url = URL(
            fileURLWithPath: "/tmp/image.gif"
        )

        XCTAssertEqual(
            ImageSchemeHandler.test_mimeType(for: url),
            "image/gif"
        )
    }

    /// test_7: mimeType returns SVG MIME type
    func test_7_mimeType_returns_svg_mime_type() {
        let url = URL(
            fileURLWithPath: "/tmp/image.svg"
        )

        XCTAssertEqual(
            ImageSchemeHandler.test_mimeType(for: url),
            "image/svg+xml"
        )
    }

    /// test_8: originalURLString returns nil for wrong scheme
    func test_8_originalURLString_returns_nil_for_wrong_scheme() throws {
        let url = try XCTUnwrap(
            URL(string: "https://example.com/image.png")
        )

        let result = ImageSchemeHandler.test_originalURLString(
            from: url
        )

        XCTAssertNil(result)
    }

    /// test_9: mimeType returns JPEG MIME type for unknown extension
    func test_9_mimeType_returns_jpeg_mime_type_for_unknown_extension() {
        let url = URL(
            fileURLWithPath: "/tmp/image.unknown"
        )

        XCTAssertEqual(
            ImageSchemeHandler.test_mimeType(for: url),
            "image/jpeg"
        )
    }

    /// test_10: stop does not crash
    func test_10_stop_does_not_crash() {
        let handler = ImageSchemeHandler()
        let webView = WKWebView()

        XCTAssertNoThrow(
            handler.webView(
                webView,
                stop: MockURLSchemeTask(
                    url: URL(string: "acimg://https/example.com/image.png")!
                )
            )
        )
    }

    /// test_11: response callbacks are delivered on the main thread
    func test_11_responseCallbacks_deliveredOnMainThread() async throws {
        let handler = ImageSchemeHandler()
        let webView = WKWebView()

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("acimg-test-\(UUID().uuidString).png")
        try Data([0x89, 0x50]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await CacheIndex.shared.put(
            "https://example.com/main-thread.png",
            fileURL: fileURL
        )

        let task = MockURLSchemeTask(
            url: URL(string: "acimg://https/example.com/main-thread.png")!
        )

        handler.webView(webView, start: task)

        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(task.events.contains(.finish))
        XCTAssertTrue(task.stayedOnMainThread)
    }

    /// test_12: stop cancels the serving task and skips all callbacks
    func test_12_stop_cancelsServingTask_andSkipsCallbacks() {
        let handler = ImageSchemeHandler()
        let webView = WKWebView()

        let task = MockURLSchemeTask(
            url: URL(string: "acimg://https/example.com/never-cached.png")!
        )

        handler.webView(webView, start: task)
        XCTAssertEqual(handler.test_servingTaskCount, 1)

        handler.webView(webView, stop: task)

        XCTAssertEqual(handler.test_servingTaskCount, 0)
        XCTAssertTrue(task.events.isEmpty)
    }

    /// test_13: originalURLString preserves percent-encoding (%20) — cache key parity
    func test_13_originalURLString_preservesPercentEncoding() throws {
        let original = "https://example.com/my%20image.png?q=a%20b"

        let customURLString = InAppHTMLRewriter.makeCustomSchemeURL(
            from: original
        )
        XCTAssertEqual(customURLString, "acimg://https/example.com/my%20image.png?q=a%20b")

        let custom = try XCTUnwrap(URL(string: customURLString))
        let restored = ImageSchemeHandler.test_originalURLString(from: custom)

        XCTAssertEqual(restored, original)
    }

    /// URL scheme task mock.
    private final class MockURLSchemeTask: NSObject, WKURLSchemeTask {

        /// Captured scheme task event.
        enum Event {
            case response
            case data
            case finish
            case failure
        }

        let request: URLRequest
        private(set) var events: [Event] = []
        private(set) var stayedOnMainThread = true

        init(url: URL) {
            self.request = URLRequest(
                url: url
            )

            super.init()
        }

        func didReceive(
            _ response: URLResponse
        ) {
            append(.response)
        }

        func didReceive(
            _ data: Data
        ) {
            append(.data)
        }

        func didFinish() {
            append(.finish)
        }

        func didFailWithError(
            _ error: Error
        ) {
            append(.failure)
        }

        private func append(_ event: Event) {
            if !Thread.isMainThread {
                stayedOnMainThread = false
            }
            events.append(event)
        }
    }
}
