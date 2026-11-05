//
//  WebViewPrewarmer.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Prewarms `WKWebView` internals before the first real in-app rendering.
///
/// Creating and loading a lightweight hidden web view helps initialize WebKit
/// resources earlier, reducing delay when the first in-app message is shown.
@available(iOSApplicationExtension, unavailable)
@MainActor
final class WebViewPrewarmer: NSObject, WKNavigationDelegate {

    /// Temporary web view used only for prewarming.
    private var webView: WKWebView?

    /// Continuation resumed when the prewarm load finishes or fails.
    private var continuation: CheckedContinuation<Void, Never>?

    /// Starts WebKit prewarming and suspends until the lightweight page finishes loading.
    ///
    /// The method creates an offscreen `WKWebView`, loads an empty HTML document,
    /// and releases the web view after navigation finishes or fails.
    func prewarm() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation

            let webView = WKWebView(frame: .zero)
            webView.navigationDelegate = self
            self.webView = webView

            webView.loadHTMLString(
                "<html><body></body></html>",
                baseURL: nil
            )
        }
    }

    /// Handles successful completion of the prewarm navigation.
    ///
    /// - Parameters:
    ///   - webView: Web view that completed loading.
    ///   - navigation: Completed navigation object.
    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        continuation?.resume()
        continuation = nil

        self.webView = nil
    }

    /// Handles failed prewarm navigation.
    ///
    /// The continuation is resumed even on failure because prewarming is optional
    /// and should not block SDK execution.
    ///
    /// - Parameters:
    ///   - webView: Web view that failed loading.
    ///   - navigation: Failed navigation object.
    ///   - error: Navigation error.
    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    /// Handles a failure of the provisional navigation phase.
    ///
    /// `didFail` is not guaranteed to fire for provisional-phase failures
    /// (e.g. an unreachable page), so this callback is required to release
    /// the continuation; otherwise `prewarm()` would suspend forever.
    ///
    /// - Parameters:
    ///   - webView: Web view whose navigation failed.
    ///   - navigation: Failed provisional navigation object.
    ///   - error: Navigation error.
    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish()
    }

    /// Handles termination of the web content process.
    ///
    /// When the WebContent process is killed (e.g. under memory pressure —
    /// a typical prewarm scenario) neither `didFinish` nor the failure
    /// callbacks are guaranteed to fire, so the continuation must be
    /// released here; otherwise `prewarm()` would suspend forever and the
    /// retained web view would leak.
    ///
    /// - Parameter webView: Web view whose content process terminated.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish()
    }

    /// Releases the continuation and the temporary web view exactly once.
    private func finish() {
        continuation?.resume()
        continuation = nil

        self.webView = nil
    }
}
