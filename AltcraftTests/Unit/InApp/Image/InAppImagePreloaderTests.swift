//
//  InAppImagePreloaderTests.swift
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
 * InAppImagePreloaderTests
 *
 * Positive scenarios:
 * - test_1: uniqueValidUrls removes duplicate URLs.
 * - test_2: uniqueValidUrls preserves original order.
 * - test_3: uniqueValidUrls returns empty array for empty input.
 * - test_4: isSupportedImageExtension returns true for supported extensions.
 * - test_5: fileExtension prefers supported URL extension over MIME type.
 * - test_6: fileExtension resolves PNG MIME type.
 * - test_7: fileExtension resolves WEBP MIME type.
 * - test_8: fileExtension resolves GIF MIME type.
 * - test_9: fileExtension resolves SVG MIME type.
 * - test_10: fileExtension resolves HEIC MIME type.
 * - test_11: fileExtension resolves HEIF MIME type.
 * - test_12: fileExtension resolves JPEG MIME type.
 * - test_13: isImageMimeType returns true for image MIME type.
 *
 * Edge scenarios:
 * - test_14: uniqueValidUrls skips invalid URLs.
 * - test_15: isSupportedImageExtension returns false for unsupported extension.
 * - test_16: fileExtension returns JPG for unknown MIME type.
 * - test_17: fileExtension returns JPG for missing MIME type.
 * - test_18: isImageMimeType returns false for non-image MIME type.
 * - test_19: isImageMimeType returns true for missing MIME type.
 *
 */
@available(iOSApplicationExtension, unavailable)
final class InAppImagePreloaderTests: IsolatedTestCase {

    /// test_1: uniqueValidUrls removes duplicate URLs
    func test_1_uniqueValidUrls_removes_duplicate_urls() {
        let urls = [
            "https://example.com/image-1.png",
            "https://example.com/image-1.png",
            "https://example.com/image-2.png"
        ]

        let result = InAppImagePreloader.test_uniqueValidUrls(
            from: urls
        )

        XCTAssertEqual(
            result,
            [
                "https://example.com/image-1.png",
                "https://example.com/image-2.png"
            ]
        )
    }

    /// test_2: uniqueValidUrls preserves original order
    func test_2_uniqueValidUrls_preserves_original_order() {
        let urls = [
            "https://example.com/image-3.png",
            "https://example.com/image-1.png",
            "https://example.com/image-2.png",
            "https://example.com/image-1.png"
        ]

        let result = InAppImagePreloader.test_uniqueValidUrls(
            from: urls
        )

        XCTAssertEqual(
            result,
            [
                "https://example.com/image-3.png",
                "https://example.com/image-1.png",
                "https://example.com/image-2.png"
            ]
        )
    }

    /// test_3: uniqueValidUrls returns empty array for empty input
    func test_3_uniqueValidUrls_returns_empty_array_for_empty_input() {
        let result = InAppImagePreloader.test_uniqueValidUrls(
            from: []
        )

        XCTAssertTrue(
            result.isEmpty
        )
    }

    /// test_4: isSupportedImageExtension returns true for supported extensions
    func test_4_isSupportedImageExtension_returns_true_for_supported_extensions() {
        let extensions = [
            "jpg",
            "jpeg",
            "png",
            "webp",
            "gif",
            "svg",
            "heic",
            "heif"
        ]

        for ext in extensions {
            XCTAssertTrue(
                InAppImagePreloader.test_isSupportedImageExtension(ext),
                "Expected \(ext) to be supported"
            )
        }
    }

    /// test_5: fileExtension prefers supported URL extension over MIME type
    func test_5_fileExtension_prefers_supported_url_extension_over_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image.png",
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(
            result,
            "png"
        )
    }

    /// test_6: fileExtension resolves PNG MIME type
    func test_6_fileExtension_resolves_png_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/png"
        )

        XCTAssertEqual(
            result,
            "png"
        )
    }

    /// test_7: fileExtension resolves WEBP MIME type
    func test_7_fileExtension_resolves_webp_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/webp"
        )

        XCTAssertEqual(
            result,
            "webp"
        )
    }

    /// test_8: fileExtension resolves GIF MIME type
    func test_8_fileExtension_resolves_gif_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/gif"
        )

        XCTAssertEqual(
            result,
            "gif"
        )
    }

    /// test_9: fileExtension resolves SVG MIME type
    func test_9_fileExtension_resolves_svg_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/svg+xml"
        )

        XCTAssertEqual(
            result,
            "svg"
        )
    }

    /// test_10: fileExtension resolves HEIC MIME type
    func test_10_fileExtension_resolves_heic_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/heic"
        )

        XCTAssertEqual(
            result,
            "heic"
        )
    }

    /// test_11: fileExtension resolves HEIF MIME type
    func test_11_fileExtension_resolves_heif_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/heif"
        )

        XCTAssertEqual(
            result,
            "heif"
        )
    }

    /// test_12: fileExtension resolves JPEG MIME type
    func test_12_fileExtension_resolves_jpeg_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "image/jpeg"
        )

        XCTAssertEqual(
            result,
            "jpg"
        )
    }

    /// test_13: isImageMimeType returns true for image MIME type
    func test_13_isImageMimeType_returns_true_for_image_mime_type() {
        XCTAssertTrue(
            InAppImagePreloader.test_isImageMimeType("image/png")
        )
    }

    /// test_14: uniqueValidUrls skips invalid URLs
    func test_14_uniqueValidUrls_skips_invalid_urls() {
        let urls = [
            "https://example.com/image.png",
            "",
            "https://example.com/image.png",
            "https://example.com/other.png"
        ]

        let result = InAppImagePreloader.test_uniqueValidUrls(
            from: urls
        )

        XCTAssertEqual(
            result,
            [
                "https://example.com/image.png",
                "https://example.com/other.png"
            ]
        )
    }

    /// test_15: isSupportedImageExtension returns false for unsupported extension
    func test_15_isSupportedImageExtension_returns_false_for_unsupported_extension() {
        XCTAssertFalse(
            InAppImagePreloader.test_isSupportedImageExtension("pdf")
        )
    }

    /// test_16: fileExtension returns JPG for unknown MIME type
    func test_16_fileExtension_returns_jpg_for_unknown_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: "application/octet-stream"
        )

        XCTAssertEqual(
            result,
            "jpg"
        )
    }

    /// test_17: fileExtension returns JPG for missing MIME type
    func test_17_fileExtension_returns_jpg_for_missing_mime_type() {
        let result = InAppImagePreloader.test_fileExtension(
            from: "https://example.com/image",
            mimeType: nil
        )

        XCTAssertEqual(
            result,
            "jpg"
        )
    }

    /// test_18: isImageMimeType returns false for non-image MIME type
    func test_18_isImageMimeType_returns_false_for_non_image_mime_type() {
        XCTAssertFalse(
            InAppImagePreloader.test_isImageMimeType("text/html")
        )
    }

    /// test_19: isImageMimeType returns true for missing MIME type
    func test_19_isImageMimeType_returns_true_for_missing_mime_type() {
        XCTAssertTrue(
            InAppImagePreloader.test_isImageMimeType(nil)
        )
    }
}
