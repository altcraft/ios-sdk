//
//  InAppStatic.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles loading, caching, and retry logic for in-app static resources.
@available(iOSApplicationExtension, unavailable)
internal actor InAppStaticProcess {
    static let shared = InAppStaticProcess()

    private let ttlMs: Int64 = 24 * 60 * 60 * 1000
    private var cache: InAppModel.InAppStaticProcess?

    /// Returns cached, stored, or downloaded in-app static resources.
    ///
    /// Static resources are loaded from memory first, then from Core Data,
    /// and finally from the network. If loading fails, retry is scheduled
    /// when `enableRetry` is `true`.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry when resources could not be loaded.
    /// - Returns: Available static bundle, or `nil` if resources could not be loaded.
    func getInAppStatic(
        enableRetry: Bool = true
    ) async -> InAppModel.InAppStaticProcess? {
        if let cached = cache {
            return cached
        }

        let context = inAppDatabase.getContext()

        if let data = await InAppStaticDAO.getInAppStaticData(context: context) {
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            if now - data.createdAt < ttlMs {
                cache = data.bundle
                return data.bundle
            }

            await InAppStaticDAO.clearInAppStaticEntity(context: context)
        }

        if let downloaded = await downloadStaticBundle() {
            cache = downloaded
            RetryCounters.shared.reset(InAppConstants.RetryKey.inAppStatic)
            return downloaded
        }

        if enableRetry {
            inAppStaticRetry()
        }

        return nil
    }

    /// Downloads in-app static resources from configured static endpoints.
    ///
    /// Loads in-app library JS, block JS, and block CSS.
    /// If any resource is missing or empty, loading is treated as failed.
    ///
    /// - Returns: Downloaded static bundle, or `nil` if downloading failed.
    private func downloadStaticBundle() async -> InAppModel.InAppStaticProcess? {
        do {
            try InAppEnvironment.fresh().checkCoreDataError()

            let blockCss  = await CoreRequestBuilder.getRawText(
                path: InAppConstants.UrlPath.blockCss
            )
            let blockJs   = await CoreRequestBuilder.getRawText(
                path: InAppConstants.UrlPath.blockJs
            )
            let libraryJs = await CoreRequestBuilder.getRawText(
                path: InAppConstants.UrlPath.libJs
            )

            guard let blockCss, !blockCss.isEmpty,
                  let blockJs, !blockJs.isEmpty,
                  let libraryJs, !libraryJs.isEmpty
            else {
                InAppLog.error(#function, error: InAppModuleEvents.invalidStaticField)
                return nil
            }

            let bundle = InAppModel.InAppStaticProcess(
                inAppLibraryJs: libraryJs,
                blockJs: blockJs,
                blockCss: blockCss
            )

            await InAppStaticDAO.saveInAppStaticEntity(
                blockCss: bundle.blockCss,
                blockJs: bundle.blockJs,
                inAppLibraryJs: bundle.inAppLibraryJs
            )

            return bundle
        } catch {
            InAppLog.error(#function, error: error)
            return nil
        }
    }

    /// Injects static in-app resources into the provided web view.
    ///
    /// - Parameters:
    ///   - webView: Web view where resources should be injected.
    ///   - staticBundle: Static JS/CSS resources to inject.
    @MainActor
    func inject(
        webView: WKWebView,
        staticBundle: InAppModel.InAppStaticProcess
    ) async {
        let script = Self.buildInjectionScript(staticBundle)

        guard !script.isEmpty else {
            return
        }

        do {
            _ = try await webView.evaluateJavaScript(script)
        } catch {
            InAppLog.error(#function, error: error)
        }
    }

    /// Builds a self-executing JavaScript function that injects CSS and JS into the loaded page.
    ///
    /// - Parameter staticBundle: Static JS/CSS resources to embed.
    /// - Returns: JavaScript string ready for evaluation in a web view.
    nonisolated private static func buildInjectionScript(
        _ staticBundle: InAppModel.InAppStaticProcess
    ) -> String {
        var script = "(function() {"

        if !staticBundle.blockCss.isEmpty {
            script += createCssInjectionScript(staticBundle.blockCss)
            script += "\n"
        }

        if !staticBundle.inAppLibraryJs.isEmpty {
            script += staticBundle.inAppLibraryJs
            script += "\n"
        }

        if !staticBundle.blockJs.isEmpty {
            script += staticBundle.blockJs
            script += "\n"
        }

        script += "})();"

        return script
    }

    /// Creates JavaScript code that injects a CSS `<style>` element into document head.
    ///
    /// - Parameter css: CSS text to inject.
    /// - Returns: JavaScript string that creates and appends the style element.
    nonisolated private static func createCssInjectionScript(
        _ css: String
    ) -> String {
        return """
        var style = document.createElement('style');
        style.type = 'text/css';
        style.appendChild(document.createTextNode(\(toJsString(css))));
        document.head.appendChild(style);
        """
    }

    /// Escapes a string so it can be safely embedded into a JavaScript string literal.
    ///
    /// Handles backslashes, quotes, newlines, carriage returns, and `</script>` tags.
    ///
    /// - Parameter value: String to escape.
    /// - Returns: Double-quoted JavaScript-safe string.
    nonisolated private static func toJsString(
        _ value: String
    ) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "</script>", with: "<\\/script>")

        return "\"\(escaped)\""
    }
}
