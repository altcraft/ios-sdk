//
//  CasheIndex.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Actor-based in-memory index of cached in-app image files.
///
/// Maps original remote image URL strings to local cached file URLs.
@available(iOSApplicationExtension, unavailable)
internal actor CacheIndex {

    /// Shared singleton instance.
    static let shared = CacheIndex()

    /// Mapping between original image URL strings and cached local file URLs.
    private var map: [String: URL] = [:]

    /// Stores or updates a cached file URL for the specified key.
    ///
    /// - Parameters:
    ///   - key: Original remote image URL string.
    ///   - fileURL: Local cached file URL associated with the key.
    func put(_ key: String, fileURL: URL) {
        map[key] = fileURL
    }

    /// Returns a cached file URL for the specified key.
    ///
    /// - Parameter key: Original remote image URL string.
    /// - Returns: Local cached file URL, or `nil` if no cached file is registered.
    func get(_ key: String) -> URL? {
        map[key]
    }

    /// Removes all cached URL mappings from the index.
    func clear() {
        map.removeAll()
    }
}

