//
//  ImageFormat.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import MobileCoreServices
import Foundation
import SwiftUI

/// Lightweight detector for common image formats.
/// Returns a guessed file extension and (when available) a UTI hint for UNNotificationAttachment.
enum ImageFormat: String {
    case png, jpg, gif, webp, bmp, tiff, heic

    /// Lowercase file extension matching the detected format (e.g. "png").
    var fileExtension: String { rawValue }

    /// Optional Uniform Type Identifier hint for Apple APIs that accept type hints.
    /// Provided for PNG/JPEG/GIF/TIFF/BMP; `nil` for formats without a stable UTI here.
    var utiHint: String? {
        switch self {
        case .png:  return kUTTypePNG as String
        case .jpg:  return kUTTypeJPEG as String
        case .gif:  return kUTTypeGIF as String
        case .tiff: return kUTTypeTIFF as String
        case .bmp:  return kUTTypeBMP as String
        default:    return nil
        }
    }

    /// Initializes the format by inspecting the data’s bytes.
    ///
    /// Supported signatures: PNG, JPEG, GIF, WEBP (RIFF/WEBP), BMP, TIFF (II*/MM*), HEIC/HEIF (ISO BMFF "ftyp").
    /// Returns `nil` if the data is too short or no known signature matches.
    ///
    /// - Parameter data: Raw image bytes to probe.
    init?(data: Data) {
        guard data.count >= 12 else { return nil }

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            self = .png; return
        }
        // JPEG: FF D8 FF
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            self = .jpg; return
        }
        // GIF: "GIF8"
        if data.starts(with: Array("GIF8".utf8)) {
            self = .gif; return
        }
        // WEBP: "RIFF" .... "WEBP"
        if data.starts(with: Array("RIFF".utf8)),
           data.dropFirst(8).starts(with: Array("WEBP".utf8)) {
            self = .webp; return
        }
        // BMP: "BM"
        if data.starts(with: [0x42, 0x4D]) {
            self = .bmp; return
        }
        // TIFF: "II*\0" or "MM\0*"
        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) ||
           data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            self = .tiff; return
        }
        // ISO BMFF: offset 4..7 == "ftyp" → check brand for HEIC family
        if data[4..<8].elementsEqual("ftyp".utf8) {
            let brand = data[8..<12]
            if brand.elementsEqual("heic".utf8) ||
               brand.elementsEqual("heif".utf8) ||
               brand.elementsEqual("hevc".utf8) ||
               brand.elementsEqual("mif1".utf8) ||
               brand.elementsEqual("msf1".utf8) {
                self = .heic; return
            }
        }

        return nil
    }
}


