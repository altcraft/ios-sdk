//
//  ImageSchemeHandler.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import WebKit
import UniformTypeIdentifiers

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles custom image URL scheme requests for in-app web content.
///
/// Resolves `acimg` URLs to cached local image files and returns them to `WKWebView`.
///
/// Lifecycle rules:
/// - A serving task started for a scheme task is cancelled when WebKit stops it.
/// - No WebKit callbacks are invoked after the scheme task has been stopped.
/// - All WebKit callbacks are executed on the main thread.
@available(iOSApplicationExtension, unavailable)
internal final class ImageSchemeHandler: NSObject, WKURLSchemeHandler {

    /// Custom URL scheme used for cached in-app images.
    nonisolated static let scheme = "acimg"

    /// Serving tasks for in-flight scheme tasks, keyed by task identity.
    private let lock = NSLock()
    private var servingTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    /// Starts loading a custom scheme request.
    ///
    /// - Parameters:
    ///   - webView: Web view that initiated the request.
    ///   - urlSchemeTask: URL scheme task containing the requested custom image URL.
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)

        let task = Task { [weak self] in
            guard let self else { return }
            await self.serve(urlSchemeTask, id: id)
        }

        lock.lock()
        servingTasks[id] = task
        lock.unlock()
    }

    /// Stops loading a custom scheme request.
    ///
    /// Cancels the serving task so no WebKit callbacks fire afterwards.
    ///
    /// - Parameters:
    ///   - webView: Web view that initiated the request.
    ///   - urlSchemeTask: URL scheme task that should be stopped.
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)

        lock.lock()
        let task = servingTasks.removeValue(forKey: id)
        lock.unlock()

        task?.cancel()
    }

    /// Serves the scheme task: resolves the cached file and delivers it.
    ///
    /// - Parameters:
    ///   - urlSchemeTask: URL scheme task being served.
    ///   - id: Identity of the scheme task in the serving registry.
    private func serve(
        _ urlSchemeTask: WKURLSchemeTask,
        id: ObjectIdentifier
    ) async {
        defer { finishServing(id: id) }

        guard let url = urlSchemeTask.request.url else {
            await fail(urlSchemeTask, code: NSURLErrorBadURL)
            return
        }

        guard let originalURLString = Self.originalURLString(from: url) else {
            await notFound(urlSchemeTask, url: url)
            return
        }

        guard let fileURL = await CacheIndex.shared.get(originalURLString) else {
            await notFound(urlSchemeTask, url: url)
            return
        }

        guard !Task.isCancelled else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            let mimeType = Self.mimeType(for: fileURL)

            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: data.count,
                textEncodingName: nil
            )

            await deliver(urlSchemeTask) { task in
                task.didReceive(response)
                task.didReceive(data)
                task.didFinish()
            }
        } catch {
            await deliver(urlSchemeTask) { task in
                task.didFailWithError(error)
            }
        }
    }

    /// Runs the callback block on the main thread unless the task was stopped.
    ///
    /// The cancellation check inside the main-actor block prevents WebKit
    /// callbacks after `webView(_:stop:)` — both the check and `stop` execute
    /// on the main thread, so no callback can interleave with a stop.
    ///
    /// - Parameters:
    ///   - urlSchemeTask: URL scheme task to deliver callbacks to.
    ///   - callbacks: Callback block executed on the main thread.
    private func deliver(
        _ urlSchemeTask: WKURLSchemeTask,
        _ callbacks: @escaping @MainActor (WKURLSchemeTask) -> Void
    ) async {
        await MainActor.run {
            guard !Task.isCancelled else { return }
            callbacks(urlSchemeTask)
        }
    }

    /// Fails the scheme task with the given URL error code.
    ///
    /// - Parameters:
    ///   - urlSchemeTask: URL scheme task to fail.
    ///   - code: `NSURLErrorDomain` code.
    private func fail(
        _ urlSchemeTask: WKURLSchemeTask,
        code: Int
    ) async {
        let error = NSError(domain: NSURLErrorDomain, code: code)

        await deliver(urlSchemeTask) { task in
            task.didFailWithError(error)
        }
    }

    /// Finishes the scheme task with an empty 404 response.
    ///
    /// - Parameters:
    ///   - urlSchemeTask: URL scheme task to finish.
    ///   - url: Requested URL used to build the response.
    private func notFound(
        _ urlSchemeTask: WKURLSchemeTask,
        url: URL
    ) async {
        let response = HTTPURLResponse(
            url: url,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        await deliver(urlSchemeTask) { task in
            task.didReceive(response)
            task.didReceive(Data())
            task.didFinish()
        }
    }

    /// Removes the scheme task from the serving registry.
    ///
    /// - Parameter id: Identity of the finished scheme task.
    private func finishServing(id: ObjectIdentifier) {
        lock.lock()
        servingTasks.removeValue(forKey: id)
        lock.unlock()
    }

    /// Restores the original remote image URL string from a custom image URL.
    ///
    /// The original URL is rebuilt from the percent-encoded absolute string —
    /// `URL.path` returns a percent-**decoded** path, which would corrupt
    /// cache keys for encoded URLs (`%20` and similar).
    ///
    /// - Parameter customURL: Custom `acimg` URL received from `WKWebView`.
    /// - Returns: Original remote image URL string, or `nil` if the custom URL is invalid.
    private static func originalURLString(from customURL: URL) -> String? {
        guard customURL.scheme == scheme else { return nil }
        guard let originalScheme = customURL.host else { return nil }

        let prefix = "\(scheme)://\(originalScheme)/"
        guard customURL.absoluteString.hasPrefix(prefix) else { return nil }

        let remainder = customURL.absoluteString.dropFirst(prefix.count)

        return "\(originalScheme)://\(remainder)"
    }

    /// Returns MIME type for a cached image file.
    ///
    /// - Parameter fileURL: Local cached image file URL.
    /// - Returns: MIME type matching the file extension.
    private static func mimeType(for fileURL: URL) -> String {
        if #available(iOS 14.0, *) {
            if let type = UTType(filenameExtension: fileURL.pathExtension),
               let mime = type.preferredMIMEType {
                return mime
            }
        }

        switch fileURL.pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "webp":
            return "image/webp"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        default:
            return "image/jpeg"
        }
    }
}

#if DEBUG
@available(iOSApplicationExtension, unavailable)
extension ImageSchemeHandler {

    /// Test hook: extracts the original URL string from a custom-scheme URL.
    ///
    /// - Parameter customURL: URL using the SDK image scheme.
    /// - Returns: Original remote URL string, or `nil` when parsing fails.
    static func test_originalURLString(
        from customURL: URL
    ) -> String? {
        originalURLString(from: customURL)
    }

    /// Test hook: resolves the MIME type for a file URL.
    ///
    /// - Parameter fileURL: Local file URL.
    /// - Returns: MIME type string.
    static func test_mimeType(
        for fileURL: URL
    ) -> String {
        mimeType(for: fileURL)
    }

    /// Test hook: number of scheme tasks currently being served.
    var test_servingTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return servingTasks.count
    }
}
#endif
