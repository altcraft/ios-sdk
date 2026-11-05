//
//  InAppFullscreenLifecycleTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import WebKit
@testable import AltcraftInApp

/**
 * InAppFullscreenLifecycleTests
 *
 * Verifies fullscreen In-App container cleanup rules (issue #27):
 * cleanup must run only on real dismissal or host hierarchy teardown —
 * never on a temporary disappearance.
 *
 * Edge scenarios:
 * - test_1: disappearance without dismissal keeps the In-App alive.
 * - test_2: JavaScript alert(...) over fullscreen In-App does not close it;
 *   the In-App survives until a real dismissal.
 * - test_3: real dismissal cleans up exactly once.
 * - test_4: detached container (view not attached to any window) cleans up
 *   on disappearance so the presentation queue is never stuck.
 * - test_5: presentation refused by UIKit (presenter already busy) returns
 *   promptly instead of leaving the continuation and the queue hanging.
 * - test_6: embedded slide-up container is cleaned up when its host
 *   hierarchy goes away without an explicit close (navigation pop, root
 *   replacement) so the presentation queue slot is released.
 * - test_7: embedded container whose host view remains attached to the
 *   window survives a temporary disappearance.
 */
@MainActor
final class InAppFullscreenLifecycleTests: IsolatedTestCase {

    /// Number of times the container invoked its close callback.
    private var closeCount = 0

    // MARK: - Positive scenarios

    /// test_2: JavaScript alert(...) over fullscreen In-App must not close it.
    func test_2_javascriptAlert_doesNotCloseInApp() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer()
        root.present(container, animated: false)
        drainMainLoop()

        guard let webView = container.view.subviews
            .compactMap({ $0 as? WKWebView })
            .first
        else {
            return XCTFail("Hosted web view not found")
        }

        let captor = FrameCaptor()
        webView.configuration.userContentController.add(
            captor,
            name: "altcraftFrameCaptor"
        )
        webView.loadHTMLString(
            "<html><body><script>"
                + "webkit.messageHandlers.altcraftFrameCaptor.postMessage('frame')"
                + "</script></body></html>",
            baseURL: nil
        )
        try waitUntil { captor.frameInfo != nil }
        let frame = try XCTUnwrap(captor.frameInfo)

        container.webView(
            webView,
            runJavaScriptAlertPanelWithMessage: "js-alert",
            initiatedByFrame: frame,
            completionHandler: {}
        )
        try waitUntil { container.presentedViewController != nil }
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            0,
            "JS alert must not close the In-App"
        )

        container.dismiss(animated: false)
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            0,
            "In-App must remain alive after its alert is dismissed"
        )

        root.dismiss(animated: false)
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "Real dismiss must close the In-App exactly once"
        )
    }

    /// test_3: real dismissal cleans up exactly once.
    func test_3_realDismiss_cleansUpExactlyOnce() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer()
        root.present(container, animated: false)
        drainMainLoop()

        root.dismiss(animated: false)
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "Real dismiss must close the In-App exactly once"
        )
    }

    // MARK: - Edge scenarios

    /// test_1: disappearance without dismissal keeps the In-App alive.
    func test_1_viewDisappearsWithoutDismiss_keepsInAppAlive() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer()
        container.loadViewIfNeeded()

        // Orphan container: parent == nil, nothing presented from it, its
        // view is attached to the window. A temporary disappearance must not
        // destroy the In-App.
        root.view.addSubview(container.view)
        drainMainLoop()

        container.beginAppearanceTransition(false, animated: false)
        container.endAppearanceTransition()
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            0,
            "In-App must survive a disappearance that is not a dismissal"
        )
    }

    /// test_4: detached container (view not attached to any window) cleans up
    /// on disappearance so the presentation queue is never stuck.
    func test_4_detachedContainer_cleansUpOnDisappear() throws {
        let container = makeContainer()
        container.loadViewIfNeeded()

        // Never presented and never attached to a window: parent == nil,
        // view.window == nil, presentedViewController == nil. This mirrors
        // host hierarchy teardown without dismissal.
        container.beginAppearanceTransition(false, animated: false)
        container.endAppearanceTransition()
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "Detached container must clean up so the queue is released"
        )
    }

    /// test_5: presentation refused by UIKit (presenter already busy) returns
    /// promptly instead of leaving the continuation and the queue hanging.
    func test_5_busyPresenter_presentationRefused_returnsPromptly() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        // Occupy the presenter: UIKit refuses any further presentation and
        // never invokes the completion, so the pre-check must return first.
        let busy = UIViewController()
        root.present(busy, animated: false)
        drainMainLoop()

        let container = makeContainer()
        container.loadViewIfNeeded()

        let refused = expectation(description: "presentation refused promptly")
        Task {
            let started = await InAppFullscreen.present(
                container: container,
                from: root
            )

            XCTAssertFalse(
                started,
                "Busy presenter must yield false, not hang"
            )
            refused.fulfill()
        }

        wait(for: [refused], timeout: 5)
    }

    /// test_6: embedded slide-up container is cleaned up when its host
    /// hierarchy goes away without an explicit close (navigation pop, root
    /// replacement) so the presentation queue slot is released.
    func test_6_childContainer_hostTeardown_cleansUp() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeSlideUpContainer()
        container.loadViewIfNeeded()

        // Embed as a child view controller (slide-up presentation style).
        root.addChild(container)
        root.view.addSubview(container.view)
        container.didMove(toParent: root)
        drainMainLoop()

        // Host screen leaves the window (e.g. navigation pop): the child's
        // appearance ends while it is still embedded in its parent.
        container.beginAppearanceTransition(false, animated: false)
        container.view.removeFromSuperview()
        container.endAppearanceTransition()
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "Host hierarchy teardown must release the queue slot"
        )
    }

    /// test_7: embedded container whose host view remains attached to the
    /// window survives a temporary disappearance.
    func test_7_childContainer_hostVisible_keepsInAppAlive() throws {
        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeSlideUpContainer()
        container.loadViewIfNeeded()

        root.addChild(container)
        root.view.addSubview(container.view)
        container.didMove(toParent: root)
        drainMainLoop()

        // Host screen is covered by something else (e.g. a sheet): the
        // child's appearance ends while its view stays in the window.
        container.beginAppearanceTransition(false, animated: false)
        container.endAppearanceTransition()
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            0,
            "Embedded In-App must survive while its host view is visible"
        )
    }

    // MARK: - Helpers

    /// Creates a visible window with an empty root controller.
    private func makeWindow() -> (UIWindow, UIViewController) {
        let window = UIWindow(frame: UIScreen.main.bounds)
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        return (window, root)
    }

    /// Creates a fullscreen In-App container counting close callbacks.
    private func makeContainer() -> InAppContainerViewController {
        makeContainer(displayType: .fullscreen)
    }

    /// Creates a slide-up In-App container counting close callbacks.
    private func makeSlideUpContainer() -> InAppContainerViewController {
        makeContainer(displayType: .slideUp)
    }

    /// Creates an In-App container of the given display type counting close
    /// callbacks.
    private func makeContainer(
        displayType: InAppDisplayType
    ) -> InAppContainerViewController {
        closeCount = 0

        let webView = WKWebView(frame: .zero)

        return InAppContainerViewController(
            webView: webView,
            companyId: 1,
            smid: "lifecycle-test-smid",
            displayType: displayType,
            onShown: nil,
            onClose: { [weak self] in
                self?.closeCount += 1
            }
        )
    }

    /// Pumps the main run loop briefly so pending UIKit work completes.
    private func drainMainLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    /// Polls the condition on the main run loop until it holds or times out.
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        if !condition() {
            XCTFail("Condition not met within \(timeout) seconds")
        }
    }
}

/// Captures a `WKFrameInfo` delivered with a script message.
private final class FrameCaptor: NSObject, WKScriptMessageHandler {

    /// Frame info of the first received message.
    var frameInfo: WKFrameInfo?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if frameInfo == nil {
            frameInfo = message.frameInfo
        }
    }
}

/**
 * InAppFullscreenRevealTests
 *
 * Verifies reveal behavior of the fullscreen In-App container: the SDK
 * always reveals the web view first (Android parity), then invokes the
 * animation listener synchronously on the same run-loop pass. The listener
 * may re-hide and animate the content; a block that skips animation must
 * not delay the reveal.
 *
 * Scenarios:
 * - test_1: without a registered animation listener the reveal shows the
 *   web view immediately (alpha 1).
 * - test_2: the animation listener is invoked synchronously during the
 *   reveal with an animator bound to the hosted web view; a block that
 *   re-hides in `prepare` and animates ends with the content visible.
 * - test_3: a block that returns without animating must not delay the
 *   reveal — the in-app is visible the moment the listener is invoked.
 * - test_4: visibility watchdog forces the web view visible when the
 *   animation block hides the content and never animates it back.
 */
@MainActor
final class InAppFullscreenRevealTests: IsolatedTestCase {

    /// Web view captured by the animation listener during reveal.
    private var listenerView: UIView?

    /// Web view found among the container root view subviews.
    private var hostedWebView: WKWebView?

    // MARK: - Positive scenarios

    /// test_1: reveal without animation listener shows the web view
    /// immediately.
    func test_1_revealWithoutListener_showsWebViewImmediately() throws {
        let container = makeContainer(animationListener: nil)
        container.loadViewIfNeeded()
        findHostedWebView(in: container)
        let webView = try XCTUnwrap(hostedWebView)

        XCTAssertEqual(
            webView.alpha,
            0,
            "Web view must start invisible during staging"
        )

        container.markPageLoaded()

        try waitUntil { webView.alpha == 1 } // slide fallback reveal (1 s)

        XCTAssertEqual(
            webView.alpha,
            1,
            "Reveal without listener must show the web view immediately"
        )
    }

    /// test_2: the animation listener is invoked synchronously with an
    /// animator bound to the hosted web view; a block that re-hides in
    /// `prepare` and animates ends with the content visible.
    func test_2_revealWithListener_animatorBoundAndContentVisible() throws {
        var animatorView: UIView?
        var listenerAlphaAtCall: CGFloat?

        let container = makeContainer { [weak self] animator in
            animator.prepare { view in
                animatorView = view
                listenerAlphaAtCall = view.alpha
                view.alpha = 0
            }
            animator.animate(
                duration: 0.3,
                delay: 0,
                options: [],
                animations: { view in
                    view.alpha = 1
                },
                completion: nil
            )
            self?.listenerView = animatorView
        }
        container.loadViewIfNeeded()
        findHostedWebView(in: container)
        let webView = try XCTUnwrap(hostedWebView)

        container.markPageLoaded()

        try waitUntil { animatorView != nil } // slide fallback reveal (1 s)

        XCTAssertEqual(
            listenerAlphaAtCall,
            1,
            "Listener must receive an already visible web view"
        )

        let captured = try XCTUnwrap(listenerView)

        XCTAssertTrue(
            captured === webView,
            "Animator must be bound to the hosted web view"
        )

        XCTAssertEqual(
            webView.alpha,
            1,
            "Block that re-hides and animates must end with visible content"
        )
    }

    /// test_3: a block that returns without animating must not delay the
    /// reveal — the in-app is visible the moment the listener is invoked.
    func test_3_skippingListener_doesNotDelayReveal() throws {
        var listenerCalled = false

        let container = makeContainer { _ in
            listenerCalled = true
        }
        container.loadViewIfNeeded()
        findHostedWebView(in: container)
        let webView = try XCTUnwrap(hostedWebView)

        container.markPageLoaded()

        try waitUntil { listenerCalled } // slide fallback reveal (1 s)

        XCTAssertEqual(
            webView.alpha,
            1,
            "Block that skips animation must leave the in-app visible"
        )
    }

    // MARK: - Edge scenarios

    /// test_4: visibility watchdog forces the web view visible when the
    /// animation block hides the content and never animates it back.
    func test_4_visibilityWatchdog_forcesRevealForStuckListener() throws {
        let container = makeContainer { animator in
            animator.prepare { view in
                view.alpha = 0
            }
        }
        container.loadViewIfNeeded()
        findHostedWebView(in: container)
        let webView = try XCTUnwrap(hostedWebView)

        container.markPageLoaded()

        // Fallback reveal (~1 s) invokes the listener, which hides the
        // content and never animates. The watchdog must force visibility
        // after its timeout.
        try waitUntil(timeout: 10) { webView.alpha == 1 }

        XCTAssertEqual(
            webView.alpha,
            1,
            "Watchdog must reveal content stuck invisible by the listener"
        )
    }

    // MARK: - Helpers

    /// Creates a fullscreen In-App container with an optional animation
    /// listener.
    private func makeContainer(
        animationListener: (@MainActor (InAppAnimator) -> Void)? = nil
    ) -> InAppContainerViewController {
        let webView = WKWebView(frame: .zero)

        return InAppContainerViewController(
            webView: webView,
            companyId: 1,
            smid: "reveal-test-smid",
            displayType: .fullscreen,
            animationListener: animationListener
        )
    }

    /// Locates the hosted web view among the container root view subviews.
    private func findHostedWebView(in container: InAppContainerViewController) {
        hostedWebView = container.view.subviews
            .compactMap { $0 as? WKWebView }
            .first
    }

    /// Polls the condition on the main run loop until it holds or times out.
    private func waitUntil(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 5
    ) throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }

        if !condition() {
            XCTFail("Condition not met within \(timeout) seconds")
        }
    }
}
