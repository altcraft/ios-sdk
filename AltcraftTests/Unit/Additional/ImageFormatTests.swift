//
//  ImageFormatTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft
import MobileCoreServices

/**
 * ImageFormatTests
 *
 * Positive scenarios:
 *  - test_1: PNG signature detection → returns .png format.
 *  - test_2: JPEG signature detection → returns .jpg format.
 *  - test_3: GIF signature detection → returns .gif format.
 *  - test_4: WEBP signature detection → returns .webp format.
 *  - test_5: BMP signature detection → returns .bmp format.
 *  - test_6: TIFF signatures detection → returns .tiff for both endianness.
 *  - test_7: HEIC family signatures → returns .heic for supported brands.
 *  - test_8: UTI hints → returns correct UTIs for supported formats.
 *
 * Negative scenarios:
 *  - test_9: Short data → returns nil for insufficient data.
 *  - test_10: Unknown format → returns nil for unrecognized signatures.
 *  - test_11: Partial signatures → returns nil for incomplete data.
 */
final class ImageFormatTests: IsolatedTestCase {
    
    /// test_1: PNG signature detection returns .png format
    func test_1_png_signature_detection() {
        var pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        pngData.append(Data([0x00, 0x00, 0x00, 0x00]))
        let format = ImageFormat(data: pngData)
        XCTAssertEqual(format, .png)
    }
    
    /// test_2: JPEG signature detection returns .jpg format
    func test_2_jpeg_signature_detection() {
        var jpegData = Data([0xFF, 0xD8, 0xFF])
        jpegData.append(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        let format = ImageFormat(data: jpegData)
        XCTAssertEqual(format, .jpg)
    }
    
    /// test_3: GIF signature detection returns .gif format
    func test_3_gif_signature_detection() {
        var gifData = Data("GIF8".utf8)
        gifData.append(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        let format = ImageFormat(data: gifData)
        XCTAssertEqual(format, .gif)
    }
    
    /// test_4: WEBP signature detection returns .webp format
    func test_4_webp_signature_detection() {
        var webpData = Data("RIFF".utf8)
        webpData.append(Data([0x00, 0x00, 0x00, 0x00]))
        webpData.append(Data("WEBP".utf8))
        let format = ImageFormat(data: webpData)
        XCTAssertEqual(format, .webp)
    }
    
    /// test_5: BMP signature detection returns .bmp format
    func test_5_bmp_signature_detection() {
        var bmpData = Data([0x42, 0x4D])
        bmpData.append(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        let format = ImageFormat(data: bmpData)
        XCTAssertEqual(format, .bmp)
    }
    
    /// test_6: TIFF signatures detection returns .tiff for both endianness
    func test_6_tiff_signatures_detection() {
        var tiffLEData = Data([0x49, 0x49, 0x2A, 0x00])
        tiffLEData.append(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertEqual(ImageFormat(data: tiffLEData), .tiff)
        
        var tiffBEData = Data([0x4D, 0x4D, 0x00, 0x2A])
        tiffBEData.append(Data([0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertEqual(ImageFormat(data: tiffBEData), .tiff)
    }
    
    /// test_7: HEIC family signatures returns .heic for supported brands
    func test_7_heic_family_signatures() {
        let heicBrands = ["heic", "heif", "hevc", "mif1", "msf1"]
        
        for brand in heicBrands {
            var heicData = Data([0x00, 0x00, 0x00, 0x00])
            heicData.append(Data("ftyp".utf8))
            heicData.append(Data(brand.utf8))
            let format = ImageFormat(data: heicData)
            XCTAssertEqual(format, .heic, "Should detect HEIC for brand: \(brand)")
        }
    }
    
    /// test_8: UTI hints returns correct UTIs for supported formats
    func test_8_uti_hints() {
        XCTAssertEqual(ImageFormat.png.utiHint, kUTTypePNG as String)
        XCTAssertEqual(ImageFormat.jpg.utiHint, kUTTypeJPEG as String)
        XCTAssertEqual(ImageFormat.gif.utiHint, kUTTypeGIF as String)
        XCTAssertEqual(ImageFormat.tiff.utiHint, kUTTypeTIFF as String)
        XCTAssertEqual(ImageFormat.bmp.utiHint, kUTTypeBMP as String)
        XCTAssertNil(ImageFormat.webp.utiHint)
        XCTAssertNil(ImageFormat.heic.utiHint)
    }
    
    /// test_9: Short data returns nil for insufficient data
    func test_9_short_data_returns_nil() {
        let shortData = Data([0x89, 0x50])
        let format = ImageFormat(data: shortData)
        XCTAssertNil(format)
    }
    
    /// test_10: Unknown format returns nil for unrecognized signatures
    func test_10_unknown_format_returns_nil() {
        var unknownData = Data("UNKNOWN_FORMAT".utf8)
        unknownData.append(Data([0x00, 0x00]))
        let format = ImageFormat(data: unknownData)
        XCTAssertNil(format)
    }
    
    /// test_11: Partial signatures returns nil for incomplete data
    func test_11_partial_signatures_return_nil() {
        let partialPng = Data([0x89, 0x50, 0x4E])
        let format = ImageFormat(data: partialPng)
        XCTAssertNil(format)
    }
    
    /// test_12: File extensions returns correct values for all formats
    func test_12_file_extensions() {
        XCTAssertEqual(ImageFormat.png.fileExtension, "png")
        XCTAssertEqual(ImageFormat.jpg.fileExtension, "jpg")
        XCTAssertEqual(ImageFormat.gif.fileExtension, "gif")
        XCTAssertEqual(ImageFormat.webp.fileExtension, "webp")
        XCTAssertEqual(ImageFormat.bmp.fileExtension, "bmp")
        XCTAssertEqual(ImageFormat.tiff.fileExtension, "tiff")
        XCTAssertEqual(ImageFormat.heic.fileExtension, "heic")
    }
    
    /// test_13: Exactly 12 bytes data returns correct format
    func test_13_exactly_12_bytes_data() {
        let exactPngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x00])
        let format = ImageFormat(data: exactPngData)
        XCTAssertEqual(format, .png)
    }
    
    /// test_14: WEBP signature with extra data returns correct format
    func test_14_webp_with_extra_data() {
        var webpData = Data("RIFF".utf8)
        webpData.append(Data([0x00, 0x00, 0x00, 0x00]))
        webpData.append(Data("WEBP".utf8))
        webpData.append(Data([0x00, 0x00, 0x00, 0x00]))
        let format = ImageFormat(data: webpData)
        XCTAssertEqual(format, .webp)
    }
}
