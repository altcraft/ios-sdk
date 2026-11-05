//
//  InAppPresenter.swift
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

/// Entry point for displaying in-app campaigns.
@available(iOSApplicationExtension, unavailable)
enum InAppPresenter {

    /// Presents an in-app campaign and waits until it is dismissed.
    ///
    /// - Parameters:
    ///   - inApp: In-app campaign to present.
    ///   - delayTask: `true` if presentation was triggered by delayed task.
    @MainActor
    static func present(
        _ inApp: InAppModel.InApp,
        delayTask: Bool = false
    ) async {
        await Presenter.present(
            inApp,
            delayTask: delayTask
        )
    }

    /// Displays an in-app campaign inside a transparent staging container.
    ///
    /// The container is presented before HTML loading starts. This gives
    /// `WKWebView` the final screen width required for correct DOM measurement.
    ///
    /// For slide-up content, the web view remains invisible until JavaScript
    /// sends `slideReady`. The native container is then resized
    /// and revealed.
    ///
    /// - Parameters:
    ///   - companyId: Campaign identifier.
    ///   - smid: Send Message ID associated with the current in-app message.
    ///   - html: HTML content of the in-app campaign.
    ///   - imageURLs: URLs of images already preloaded into local cache.
    ///   - staticBundle: Static rendering resources.
    ///   - displayType: Native display type resolved from backend content.
    ///   - onShown: Called after the in-app becomes visible.
    ///   - onClose: Called when the in-app view is closed.
    ///
    /// The animation listener is captured before presentation starts so the
    /// reveal can invoke it synchronously — mirroring the Android SDK, where
    /// reveal and the shown listener share one main-thread pass.
    ///
    /// - Returns: `true` if presentation started, otherwise `false`.
    @MainActor
    static func show(
        companyId: Int,
        smid: String,
        html: String,
        imageURLs: [String],
        staticBundle: InAppModel.InAppStaticProcess,
        displayType: InAppDisplayType,
        onShown: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) async -> Bool {
        guard Check.Orientation.canShow() else {
            onClose?()
            return false
        }

        let preparedHTML = InAppHTMLRewriter.prepareHTML(
            html,
            imageURLs: imageURLs
        )

        guard let presenter = InAppTopViewControllerResolver.topViewController(),
              presenter.view.window != nil,
              !(presenter is InAppContainerViewController)
        else {
            onClose?()
            return false
        }

        let webView = InAppWebView.createWebView(
            staticBundle: staticBundle,
            smid: smid
        )

        let animationListener = await InAppAnimationRegistry.shared.getListener()

        let container = InAppContainerViewController(
            webView: webView,
            companyId: companyId,
            smid: smid,
            displayType: displayType,
            animationListener: animationListener,
            onShown: onShown,
            onClose: onClose
        )

        let started = await InAppFullscreen.present(
            container: container,
            from: presenter
        )

        guard started else {
            onClose?()
            return false
        }

        webView.loadHTMLString(preparedHTML, baseURL: nil)
        return true
    }
}
