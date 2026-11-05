//
//  InAppNavigationDelegate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit
import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles in-app web view loading lifecycle.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal final class InAppNavigationDelegate: NSObject, WKNavigationDelegate {

    /// Static JS/CSS resources injected after page loading.
    private let staticBundle: InAppModel.InAppStaticProcess

    /// Creates a navigation delegate.
    ///
    /// - Parameter staticBundle: Static JS/CSS resources injected after page loading.
    init(
        staticBundle: InAppModel.InAppStaticProcess
    ) {
        self.staticBundle = staticBundle
    }

    /// Handles finished page loading.
    ///
    /// Static resources are injected first. The parent in-app container is then
    /// notified that the page can begin waiting for `ready` or `slideReady`.
    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        Task { @MainActor in
            await InAppStaticProcess.shared.inject(
                webView: webView,
                staticBundle: staticBundle
            )

            webView.parentViewController?
                .asInAppContainerViewController?
                .markPageLoaded()
        }
    }
}

@available(iOSApplicationExtension, unavailable)
extension UIView {

    /// Finds the nearest parent view controller.
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self

        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }

            responder = current.next
        }

        return nil
    }
}

@MainActor
internal extension UIViewController {

    /// Casts the receiver to the native in-app container.
    var asInAppContainerViewController: InAppContainerViewController? {
        self as? InAppContainerViewController
    }
}

