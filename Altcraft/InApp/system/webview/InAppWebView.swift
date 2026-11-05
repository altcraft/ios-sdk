//
//  InAppWebView.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit
import WebKit
import ObjectiveC

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Association key token for the navigation delegate.
private enum NavigationDelegateAssociationKeyToken {}
/// Association key token for the script message bridge.
private enum BridgeAssociationKeyToken {}

private let navigationDelegateAssociationKeyID = Int(
    bitPattern: ObjectIdentifier(
        NavigationDelegateAssociationKeyToken.self
    )
)

private let bridgeAssociationKeyID = Int(
    bitPattern: ObjectIdentifier(
        BridgeAssociationKeyToken.self
    )
)

/// Namespace for web view factory helpers.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal enum InAppWebView {

    /// Creates a configured in-app web view.
    ///
    /// - Parameters:
    ///   - staticBundle: Static JS/CSS resources injected after page loading.
    ///   - smid: Send Message ID associated with the current in-app message.
    /// - Returns: Configured `WKWebView`.
    static func createWebView(
        staticBundle: InAppModel.InAppStaticProcess,
        smid: String
    ) -> WKWebView {
        let contentController = WKUserContentController()

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.websiteDataStore = .default()
        configuration.userContentController = contentController
        configuration.setURLSchemeHandler(
            ImageSchemeHandler(),
            forURLScheme: InAppWebConstants.imageScheme
        )

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        let bridge = InAppBridge { [weak webView] eventJson in
            guard let webView else {
                return
            }

            InAppEventProcessing.process(
                data: eventJson,
                webView: webView,
                smid: smid
            )
        }

        contentController.add(
            bridge,
            name: InAppConstants.JSInterfaceName.inAppBridge
        )

        retainBridge(
            bridge,
            in: webView
        )

        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        let navigationDelegate = InAppNavigationDelegate(
            staticBundle: staticBundle
        )

        webView.navigationDelegate = navigationDelegate

        retainDelegate(
            navigationDelegate,
            in: webView
        )

        return webView
    }

    /// Retains navigation delegate for the lifetime of the web view.
    ///
    /// - Parameters:
    ///   - delegate: Navigation delegate to retain.
    ///   - webView: Web view that owns the delegate.
    private static func retainDelegate(
        _ delegate: AnyObject,
        in webView: WKWebView
    ) {
        let key = UnsafeRawPointer(
            bitPattern: navigationDelegateAssociationKeyID
        )!

        objc_setAssociatedObject(
            webView,
            key,
            delegate,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    /// Retains script message bridge for the lifetime of the web view.
    ///
    /// - Parameters:
    ///   - bridge: Script message bridge to retain.
    ///   - webView: Web view that owns the bridge.
    private static func retainBridge(
        _ bridge: AnyObject,
        in webView: WKWebView
    ) {
        let key = UnsafeRawPointer(
            bitPattern: bridgeAssociationKeyID
        )!

        objc_setAssociatedObject(
            webView,
            key,
            bridge,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

