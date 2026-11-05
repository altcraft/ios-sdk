//
//  InAppHTMLRewriter.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// URL scheme constant for cached in-app images.
@available(iOSApplicationExtension, unavailable)
internal enum InAppWebConstants {

    /// Custom URL scheme used for loading cached in-app images.
    static let imageScheme = "acimg"
}

/// Prepares in-app HTML for rendering inside `WKWebView`.
///
/// The rewriter performs the following operations:
/// - inserts a device-width viewport when one is missing;
/// - replaces remote image URLs with SDK custom-scheme URLs.
///
/// The viewport is required for slide-up campaigns because JavaScript reports
/// dimensions in CSS pixels while native iOS layout uses UIKit points.
/// With `width=device-width` and initial scale `1`, one CSS pixel corresponds
/// to one UIKit point for the in-app layout.
internal enum InAppHTMLRewriter {

    /// Prepares raw in-app HTML for display.
    ///
    /// The method first inserts a viewport meta tag when the document does not
    /// already contain one. It then rewrites configured image URLs to the SDK
    /// custom image scheme.
    ///
    /// - Parameters:
    ///   - html: Original in-app HTML.
    ///   - imageURLs: Remote image URLs that should be rewritten.
    /// - Returns: HTML prepared for rendering inside `WKWebView`.
    static func prepareHTML(
        _ html: String,
        imageURLs: [String]
    ) -> String {
        let htmlWithViewport = ensureDeviceViewport(in: html)

        return rewriteImageURLs(
            in: htmlWithViewport,
            imageURLs: imageURLs
        )
    }

    /// Adds a device-width viewport meta tag when the document has none.
    ///
    /// Slide-up geometry is calculated by JavaScript in CSS pixels. Without an
    /// explicit viewport, WebKit may use a wider virtual layout viewport, making
    /// CSS dimensions differ significantly from UIKit points.
    ///
    /// Existing viewport declarations are preserved.
    ///
    /// - Parameter html: Original HTML document.
    /// - Returns: HTML containing a viewport meta tag.
    static func ensureDeviceViewport(
        in html: String
    ) -> String {
        let lowercasedHTML = html.lowercased()

        if lowercasedHTML.contains("name=\"viewport\"") ||
            lowercasedHTML.contains("name='viewport'") {
            return html
        }

        let viewport = """
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        """

        if let headRange = lowercasedHTML.range(of: "<head>") {
            let insertionIndex = headRange.upperBound
            let originalIndex = html.index(
                html.startIndex,
                offsetBy: lowercasedHTML.distance(
                    from: lowercasedHTML.startIndex,
                    to: insertionIndex
                )
            )

            var result = html
            result.insert(
                contentsOf: "\n\(viewport)\n",
                at: originalIndex
            )

            return result
        }

        if let htmlRange = lowercasedHTML.range(of: "<html") {
            guard let closingBracket = lowercasedHTML[
                htmlRange.lowerBound...
            ].firstIndex(of: ">") else {
                return wrapWithDocument(
                    html,
                    viewport: viewport
                )
            }

            let insertionPosition = lowercasedHTML.index(
                after: closingBracket
            )

            let originalIndex = html.index(
                html.startIndex,
                offsetBy: lowercasedHTML.distance(
                    from: lowercasedHTML.startIndex,
                    to: insertionPosition
                )
            )

            var result = html
            result.insert(
                contentsOf: "\n<head>\n\(viewport)\n</head>\n",
                at: originalIndex
            )

            return result
        }

        return wrapWithDocument(
            html,
            viewport: viewport
        )
    }

    /// Replaces remote image URLs with SDK custom-scheme URLs.
    ///
    /// - Parameters:
    ///   - html: Original in-app HTML.
    ///   - imageURLs: Remote image URLs that should be rewritten.
    /// - Returns: HTML with rewritten image URLs.
    static func rewriteImageURLs(
        in html: String,
        imageURLs: [String]
    ) -> String {
        var result = html

        for original in imageURLs {
            let rewritten = makeCustomSchemeURL(
                from: original
            )

            result = result.replacingOccurrences(
                of: original,
                with: rewritten
            )
        }

        return result
    }

    /// Converts a remote URL into an SDK custom-scheme URL.
    ///
    /// Example:
    /// `https://example.com/image.png` becomes
    /// `acimg://https/example.com/image.png`.
    ///
    /// - Parameter original: Original remote URL.
    /// - Returns: Custom-scheme URL, or the original string if it cannot be parsed.
    static func makeCustomSchemeURL(
        from original: String
    ) -> String {
        guard let url = URL(string: original),
              let scheme = url.scheme else {
            return original
        }

        let remainder = original.dropFirst(
            "\(scheme)://".count
        )

        return "\(InAppWebConstants.imageScheme)://\(scheme)/\(remainder)"
    }

    /// Wraps an HTML fragment in a complete document containing the viewport.
    ///
    /// - Parameters:
    ///   - html: Original HTML fragment.
    ///   - viewport: Viewport meta tag.
    /// - Returns: Complete HTML document.
    private static func wrapWithDocument(
        _ html: String,
        viewport: String
    ) -> String {
        """
        <!doctype html>
        <html>
        <head>
        \(viewport)
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }
}
