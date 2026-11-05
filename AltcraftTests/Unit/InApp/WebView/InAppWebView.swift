//
//  InAppWebView.swift
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
 * InAppWebViewTests
 *
 * Positive scenarios:
 * - test_1: createWebView configures transparent appearance.
 * - test_2: createWebView configures scroll view behavior.
 * - test_3: createWebView configures web view preferences.
 * - test_4: createWebView creates navigation delegate.
 *
 * Edge scenarios:
 * - test_5: createWebView retains navigation delegate.
 *
 */
@available(iOSApplicationExtension, unavailable)
@MainActor
final class InAppWebViewTests: IsolatedTestCase {

    private func makeStaticBundle() -> InAppModel.InAppStaticProcess {
        InAppModel.InAppStaticProcess(
            inAppLibraryJs: "",
            blockJs: "",
            blockCss: ""
        )
    }

    /// test_1: createWebView configures transparent appearance
    func test_1_createWebView_configures_transparent_appearance() {
        let webView = InAppWebView.createWebView(
            staticBundle: makeStaticBundle(),
            smid: "smid-1"
        )

        XCTAssertFalse(webView.isOpaque)
        XCTAssertEqual(webView.backgroundColor as? UIColor, UIColor.clear)
        XCTAssertEqual(webView.scrollView.backgroundColor as? UIColor, UIColor.clear)
    }

    /// test_2: createWebView configures scroll view behavior
    func test_2_createWebView_configures_scroll_view_behavior() {
        let webView = InAppWebView.createWebView(
            staticBundle: makeStaticBundle(),
            smid: "smid-1"
        )

        XCTAssertEqual(
            webView.scrollView.contentInsetAdjustmentBehavior,
            UIScrollView.ContentInsetAdjustmentBehavior.never
        )
        XCTAssertFalse(webView.allowsBackForwardNavigationGestures)
    }

    /// test_3: createWebView configures web view preferences
    func test_3_createWebView_configures_web_view_preferences() {
        let webView = InAppWebView.createWebView(
            staticBundle: makeStaticBundle(),
            smid: "smid-1"
        )

        XCTAssertFalse(
            webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically
        )
        XCTAssertTrue(
            webView.configuration.websiteDataStore === WKWebsiteDataStore.default()
        )
    }

    /// test_4: createWebView creates navigation delegate
    func test_4_createWebView_creates_navigation_delegate() {
        let webView = InAppWebView.createWebView(
            staticBundle: makeStaticBundle(),
            smid: "smid-1"
        )

        XCTAssertNotNil(webView.navigationDelegate)
        XCTAssertTrue(webView.navigationDelegate is InAppNavigationDelegate)
    }

    /// test_5: createWebView retains navigation delegate
    func test_5_createWebView_retains_navigation_delegate() {
        let webView = InAppWebView.createWebView(
            staticBundle: makeStaticBundle(),
            smid: "smid-1"
        )

        let delegate = webView.navigationDelegate

        autoreleasepool {
            _ = Array(repeating: NSObject(), count: 10_000)
        }

        XCTAssertNotNil(delegate)
        XCTAssertNotNil(webView.navigationDelegate)
    }
}
