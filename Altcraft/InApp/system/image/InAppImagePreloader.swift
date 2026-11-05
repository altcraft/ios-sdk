//
//  InAppImagePreloader.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Preloads remote in-app images into the local cache.
///
/// Downloads unique image URLs with limited parallelism,
/// stores files in the SDK cache directory, and registers cached files
/// in `CacheIndex` for later use by `ImageSchemeHandler`.
///
/// If any required image fails to load, preload returns failed image URLs.
/// This prevents showing an in-app message with missing images.
@available(iOSApplicationExtension, unavailable)
internal enum InAppImagePreloader {

    /// Result of in-app image preloading.
    ///
    /// Contains the list of image URLs that failed to load. If `failedURLs` is empty,
    /// all images were preloaded successfully.
    internal struct ImagePreloadResult {

        /// Image URLs that failed to load.
        let failedURLs: [String]

        /// Indicates whether all images were loaded successfully.
        var isSuccess: Bool {
            failedURLs.isEmpty
        }
    }

    /// Name of the cache folder inside the system caches directory.
    private static let folderName = "AltcraftInAppImageCache"

    /// Network timeout for image download requests.
    private static let timeout: TimeInterval = 15.0

    /// URLSession disk cache size.
    private static let diskCacheSize = 100 * 1024 * 1024

    /// URLSession memory cache size.
    private static let memoryCacheSize = 20 * 1024 * 1024

    /// Shared session used for image downloads.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default

        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.urlCache = URLCache(
            memoryCapacity: memoryCacheSize,
            diskCapacity: diskCacheSize,
            diskPath: folderName
        )

        return URLSession(configuration: configuration)
    }()

    /// Preloads remote image URLs into the local cache.
    ///
    /// Duplicate URLs are removed before downloading.
    ///
    /// The method returns all image URLs that failed to load.
    /// If `failedURLs` is empty, all images were preloaded successfully.
    ///
    /// - Parameters:
    ///   - urls: Remote image URL strings to preload.
    ///   - parallelism: Maximum number of concurrent image downloads.
    ///     Values lower than `1` are normalized to `1`.
    /// - Returns: Preload result containing failed image URLs.
    static func imagePreload(
        urls: [String],
        parallelism: Int = 6
    ) async -> ImagePreloadResult {
        guard !urls.isEmpty else {
            return ImagePreloadResult(failedURLs: [])
        }

        let uniqueUrls = uniqueValidUrls(from: urls)
        let invalidURLs = invalidUrls(from: urls)

        guard invalidURLs.isEmpty else {
            invalidURLs.forEach { urlString in
                logImageLoadFailure(urlString: urlString)
            }

            return ImagePreloadResult(failedURLs: invalidURLs)
        }

        guard !uniqueUrls.isEmpty else {
            return ImagePreloadResult(failedURLs: [])
        }

        do {
            try prepareCacheFolderIfNeeded()
        } catch {
            InAppLog.error(
                #function,
                error: error
            )

            return ImagePreloadResult(failedURLs: uniqueUrls)
        }

        let limit = max(1, parallelism)
        var iterator = uniqueUrls.makeIterator()
        var failedURLs: [String] = []

        await withTaskGroup(of: String?.self) { group in
            for _ in 0..<limit {
                guard let urlString = iterator.next() else {
                    break
                }

                group.addTask {
                    await process(urlString: urlString)
                }
            }

            while let failedURL = await group.next() {
                if let failedURL {
                    failedURLs.append(failedURL)
                }

                guard let urlString = iterator.next() else {
                    continue
                }

                group.addTask {
                    await process(urlString: urlString)
                }
            }
        }

        return ImagePreloadResult(failedURLs: failedURLs)
    }

    /// Downloads and caches a single image URL.
    ///
    /// On success, stores the cached file URL in `CacheIndex`.
    ///
    /// On failure, returns the failed image URL.
    ///
    /// - Parameter urlString: Remote image URL string to process.
    /// - Returns: `nil` if image was loaded successfully, otherwise failed URL.
    private static func process(urlString: String) async -> String? {
        guard let url = URL(string: urlString) else {
            return failImageLoad(urlString: urlString)
        }

        do {
            if let cachedFileURL = try cachedFileURLIfExists(for: urlString) {
                await CacheIndex.shared.put(
                    urlString,
                    fileURL: cachedFileURL
                )
                return nil
            }

            let request = URLRequest(
                url: url,
                cachePolicy: .returnCacheDataElseLoad,
                timeoutInterval: timeout
            )

            let (data, response) = try await loadData(request: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return failImageLoad(urlString: urlString)
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return failImageLoad(urlString: urlString)
            }

            guard isImageResponse(httpResponse) else {
                return failImageLoad(urlString: urlString)
            }

            let cacheFileURL = try makeFileURL(
                for: urlString,
                response: httpResponse
            )

            try data.write(
                to: cacheFileURL,
                options: .atomic
            )

            await CacheIndex.shared.put(
                urlString,
                fileURL: cacheFileURL
            )

            return nil
        } catch {
            InAppLog.error(
                #function,
                error: error,
                eventValue: ["url": urlString]
            )

            return urlString
        }
    }

    /// Handles failed in-app image loading.
    ///
    /// Logs SDK-side error and returns failed image URL.
    ///
    /// - Parameter urlString: Image URL that failed to load.
    /// - Returns: Failed image URL.
    private static func failImageLoad(urlString: String) -> String {
        logImageLoadFailure(urlString: urlString)
        return urlString
    }

    /// Logs failed in-app image loading.
    ///
    /// - Parameter urlString: Image URL that failed to load.
    private static func logImageLoadFailure(urlString: String) {
        InAppLog.error(
            #function,
            error: InAppModuleEvents.errorInAppImageLoad,
            eventValue: ["url": urlString]
        )
    }

    /// Loads image data using the best available URLSession API.
    ///
    /// - Parameter request: URL request used to load the image.
    /// - Returns: Image data and URL response.
    /// - Throws: Network or loading error.
    private static func loadData(request: URLRequest) async throws -> (Data, URLResponse) {
        if #available(iOS 15.0, *) {
            return try await session.data(for: request)
        } else {
            return try await loadDataCompat(request: request)
        }
    }

    /// Loads image data using a compatibility implementation for older iOS versions.
    ///
    /// - Parameter request: URL request used to load the image.
    /// - Returns: Image data and URL response.
    /// - Throws: Network error, missing response error, or missing data error.
    private static func loadDataCompat(request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let data, let response else {
                    continuation.resume(
                        throwing: NSError(
                            domain: NSURLErrorDomain,
                            code: NSURLErrorUnknown,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Data request returned no data or response"
                            ]
                        )
                    )
                    return
                }

                continuation.resume(returning: (data, response))
            }

            task.resume()
        }
    }

    /// Creates the image cache folder if it does not exist.
    ///
    /// - Throws: File system error if the cache folder cannot be created.
    private static func prepareCacheFolderIfNeeded() throws {
        try FileManager.default.createDirectory(
            at: try cacheDirectory(),
            withIntermediateDirectories: true
        )
    }

    /// Returns the image cache directory URL.
    ///
    /// - Returns: URL of the SDK image cache directory.
    /// - Throws: File system error if the system caches directory cannot be resolved.
    private static func cacheDirectory() throws -> URL {
        try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent(
            folderName,
            isDirectory: true
        )
    }

    /// Builds a deterministic cache file URL for an image.
    ///
    /// File name is based on SHA-256 hash of the source URL.
    ///
    /// - Parameters:
    ///   - sourceURL: Original remote image URL string.
    ///   - response: HTTP response used to infer file extension when needed.
    /// - Returns: Local cache file URL for the image.
    /// - Throws: File system error if the cache directory cannot be resolved.
    private static func makeFileURL(
        for sourceURL: String,
        response: HTTPURLResponse
    ) throws -> URL {
        let ext = fileExtension(
            from: sourceURL,
            mimeType: response.mimeType
        )

        let name = sha256(sourceURL)

        return try cacheDirectory()
            .appendingPathComponent("\(name).\(ext)")
    }

    /// Returns an existing cached image file URL if it exists.
    ///
    /// - Parameter sourceURL: Original remote image URL string.
    /// - Returns: Existing cached file URL or `nil`.
    /// - Throws: File system error if the cache directory cannot be read.
    private static func cachedFileURLIfExists(for sourceURL: String) throws -> URL? {
        let dir = try cacheDirectory()
        let name = sha256(sourceURL)
        let fm = FileManager.default

        guard fm.fileExists(atPath: dir.path) else {
            return nil
        }

        let files = try fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        )

        return files.first { fileURL in
            fileURL.lastPathComponent.hasPrefix("\(name).")
        }
    }

    /// Resolves file extension for an image URL.
    ///
    /// URL path extension has priority over response MIME type.
    ///
    /// - Parameters:
    ///   - sourceURL: Original remote image URL string.
    ///   - mimeType: MIME type received from HTTP response.
    /// - Returns: File extension used for the cached image.
    private static func fileExtension(
        from sourceURL: String,
        mimeType: String?
    ) -> String {
        if let ext = URL(string: sourceURL)?.pathExtension.lowercased(),
           isSupportedImageExtension(ext) {
            return ext
        }

        switch mimeType?.lowercased() {
        case "image/png":
            return "png"
        case "image/webp":
            return "webp"
        case "image/gif":
            return "gif"
        case "image/svg+xml":
            return "svg"
        case "image/heic":
            return "heic"
        case "image/heif":
            return "heif"
        case "image/jpeg", "image/jpg":
            return "jpg"
        default:
            return "jpg"
        }
    }

    /// Checks whether response contains an image.
    ///
    /// - Parameter response: HTTP response received from server.
    /// - Returns: `true` if response is an image.
    private static func isImageResponse(_ response: HTTPURLResponse) -> Bool {
        guard let mimeType = response.mimeType?.lowercased() else {
            return true
        }

        return mimeType.hasPrefix("image/")
    }

    /// Checks whether file extension is a supported image extension.
    ///
    /// - Parameter ext: File extension.
    /// - Returns: `true` if extension is supported.
    private static func isSupportedImageExtension(_ ext: String) -> Bool {
        switch ext {
        case "jpg", "jpeg", "png", "webp", "gif", "svg", "heic", "heif":
            return true
        default:
            return false
        }
    }

    /// Removes duplicate URLs and skips invalid URL strings.
    ///
    /// - Parameter urls: Remote image URL strings.
    /// - Returns: Unique valid URL strings in original order.
    private static func uniqueValidUrls(from urls: [String]) -> [String] {
        var result: [String] = []
        var seen = Set<String>()

        for urlString in urls {
            guard URL(string: urlString) != nil else {
                continue
            }

            guard !seen.contains(urlString) else {
                continue
            }

            seen.insert(urlString)
            result.append(urlString)
        }

        return result
    }

    /// Returns invalid URL strings.
    ///
    /// - Parameter urls: Remote image URL strings.
    /// - Returns: URL strings that cannot be converted to `URL`.
    private static func invalidUrls(from urls: [String]) -> [String] {
        urls.filter { URL(string: $0) == nil }
    }
}

#if DEBUG
extension InAppImagePreloader {

    /// Test hook: resolves the file extension for a source URL and MIME type.
    ///
    /// - Parameters:
    ///   - sourceURL: Remote image URL.
    ///   - mimeType: Optional MIME type hint.
    /// - Returns: File extension used for caching.
    static func test_fileExtension(
        from sourceURL: String,
        mimeType: String?
    ) -> String {
        fileExtension(
            from: sourceURL,
            mimeType: mimeType
        )
    }

    /// Test hook: reports whether the extension is a supported image type.
    ///
    /// - Parameter ext: File extension.
    /// - Returns: `true` when supported.
    static func test_isSupportedImageExtension(
        _ ext: String
    ) -> Bool {
        isSupportedImageExtension(ext)
    }

    /// Test hook: filters unique and valid image URLs.
    ///
    /// - Parameter urls: Candidate URLs.
    /// - Returns: Filtered URL list.
    static func test_uniqueValidUrls(
        from urls: [String]
    ) -> [String] {
        uniqueValidUrls(from: urls)
    }

    /// Test hook: returns entries rejected during validation.
    ///
    /// - Parameter urls: Candidate URLs.
    /// - Returns: Invalid URL strings.
    static func test_invalidUrls(
        from urls: [String]
    ) -> [String] {
        invalidUrls(from: urls)
    }

    /// Test hook: reports whether the MIME type denotes an image.
    ///
    /// - Parameter mimeType: MIME type to check.
    /// - Returns: `true` for image MIME types.
    static func test_isImageMimeType(
        _ mimeType: String?
    ) -> Bool {
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: [
                "Content-Type": mimeType ?? ""
            ]
        )!

        return isImageResponse(response)
    }
}
#endif
