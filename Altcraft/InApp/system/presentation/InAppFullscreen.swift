//
//  InAppFullscreen.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import ObjectiveC.runtime
import UIKit
import WebKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Presents in-app content over the current application screen.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal enum InAppFullscreen {

    /// Presents the provided in-app container over the current screen.
    ///
    /// Regular display types are presented modally. Slide-up content is added
    /// as a child view controller so its root view can later be resized to the
    /// exact frame received in the `slideReady` event. SwiftUI screens use a
    /// separate transparent overlay window because adding UIKit subviews
    /// directly to `UIHostingController.view` is unsupported.
    ///
    /// - Parameters:
    ///   - container: In-app container to display.
    ///   - presenter: View controller currently visible to the user.
    /// - Returns: `true` after successful attachment or presentation.
    ///
    /// UIKit silently refuses a modal presentation when the presenter already
    /// shows another view controller or has no window: the completion passed
    /// to `present` is then never invoked, which would leave the awaiting
    /// continuation — and the presentation queue slot — hanging forever.
    /// Feasibility is therefore verified before starting the presentation.
    static func present(
        container: InAppContainerViewController,
        from presenter: UIViewController
    ) async -> Bool {
        guard Check.Orientation.canShow() else {
            return false
        }

        guard presenter.view.window != nil,
              presenter.presentedViewController == nil else {
            return false
        }

        if container.isSlideUp {
            return attachSlideUp(
                container,
                to: presenter
            )
        }

        container.modalPresentationStyle = .overFullScreen
        container.modalTransitionStyle = .crossDissolve

        return await withCheckedContinuation { continuation in
            presenter.present(
                container,
                animated: false
            ) {
                continuation.resume(returning: true)
            }
        }
    }

    /// Attaches a slide-up controller to a UIKit host or a SwiftUI overlay.
    ///
    /// The container initially occupies the complete host view while its web
    /// view is invisible. This gives WebKit the final screen width required for
    /// DOM measurement. User interaction remains disabled until the content is
    /// revealed, so the screen below stays interactive during staging.
    ///
    /// For `UIHostingController`, the container is placed in a separate
    /// transparent window. This avoids modifying the SwiftUI-managed view
    /// hierarchy directly.
    ///
    /// Frame-based layout is used intentionally. Fullscreen Auto Layout
    /// constraints would force the root view back to fullscreen after it is
    /// resized.
    ///
    /// - Parameters:
    ///   - container: Slide-up In-App container.
    ///   - presenter: View controller currently visible to the user.
    /// - Returns: `true` when the container was attached successfully.
    private static func attachSlideUp(
        _ container: InAppContainerViewController,
        to presenter: UIViewController
    ) -> Bool {
        if isHostingController(presenter) {
            return attachSlideUpToOverlayWindow(
                container,
                above: presenter
            )
        }

        attach(
            container,
            to: presenter,
            hostView: presenter.view
        )

        return true
    }

    /// Attaches the slide-up container directly to a regular UIKit controller.
    private static func attach(
        _ container: InAppContainerViewController,
        to parent: UIViewController,
        hostView: UIView,
        overlayWindow: UIWindow? = nil
    ) {
        parent.addChild(container)

        container.configureSlideHost(
            view: hostView,
            overlayWindow: overlayWindow
        )

        container.view.frame = hostView.bounds
        container.view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]
        container.view.isUserInteractionEnabled = false

        hostView.addSubview(container.view)
        container.didMove(toParent: parent)
    }

    /// Creates a transparent overlay window for a SwiftUI-hosted screen.
    private static func attachSlideUpToOverlayWindow(
        _ container: InAppContainerViewController,
        above presenter: UIViewController
    ) -> Bool {
        guard let sourceWindow = presenter.view.window,
              let windowScene = sourceWindow.windowScene else {
            return false
        }

        let overlayController = InAppOverlayViewController()
        let overlayWindow = InAppOverlayWindow(windowScene: windowScene)

        overlayWindow.frame = sourceWindow.frame
        overlayWindow.windowLevel = UIWindow.Level(
            rawValue: sourceWindow.windowLevel.rawValue + 1
        )
        overlayWindow.backgroundColor = .clear
        overlayWindow.rootViewController = overlayController
        overlayWindow.isHidden = false

        overlayController.loadViewIfNeeded()
        overlayController.view.frame = overlayWindow.bounds
        overlayController.view.layoutIfNeeded()

        attach(
            container,
            to: overlayController,
            hostView: overlayController.view,
            overlayWindow: overlayWindow
        )

        return true
    }

    /// Returns `true` when the controller inherits from UIHostingController.
    private static func isHostingController(
        _ viewController: UIViewController
    ) -> Bool {
        var currentClass: AnyClass? = type(of: viewController)

        while let controllerClass = currentClass {
            if NSStringFromClass(controllerClass)
                .contains("UIHostingController") {
                return true
            }

            currentClass = class_getSuperclass(controllerClass)
        }

        return false
    }
}

/// Transparent window that forwards touches outside the visible In-App view.
@available(iOSApplicationExtension, unavailable)
@MainActor
private final class InAppOverlayWindow: UIWindow {

    /// Passes touches through when they land on the transparent root view.
    ///
    /// - Parameters:
    ///   - point: Hit point in the window coordinates.
    ///   - event: Touch event.
    /// - Returns: Hit view, or `nil` to forward touches to the window below.
    override func hitTest(
        _ point: CGPoint,
        with event: UIEvent?
    ) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        if hitView === rootViewController?.view {
            return nil
        }

        return hitView
    }
}

/// Root controller used by the transparent SwiftUI overlay window.
@available(iOSApplicationExtension, unavailable)
@MainActor
private final class InAppOverlayViewController: UIViewController {

    /// Creates a transparent root view for the SwiftUI overlay window.
    override func loadView() {
        let rootView = UIView(frame: .zero)
        rootView.backgroundColor = .clear
        view = rootView
    }

    override var prefersStatusBarHidden: Bool {
        false
    }
}

/// Transparent staging container that hosts an in-app `WKWebView`.
///
/// Regular display types remain fullscreen. Slide-up content starts in an
/// invisible fullscreen staging state and then resizes the complete root view
/// after JavaScript sends `slideReady`.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal final class InAppContainerViewController: UIViewController, WKUIDelegate {

    /// Delay before slide-up falls back to fullscreen presentation.
    private static let slideReadyFallbackDelay: TimeInterval = 1.0

    /// Time to wait before forcing web view visibility when a registered
    /// animation block never reveals the content.
    private static let animationVisibilityTimeout: TimeInterval = 5.0

    /// Web view displaying in-app content.
    private let hostedWebView: WKWebView

    /// Campaign identifier.
    private let companyId: Int

    /// Send Message ID associated with the current in-app message.
    private let smid: String

    /// Native display type used for the current in-app.
    private let displayType: InAppDisplayType

    /// Animation listener supplied by the host application.
    ///
    /// Captured before presentation begins so the reveal can invoke it
    /// synchronously on the same main-actor pass — mirroring the Android
    /// SDK. The listener receives an already visible web view: it may
    /// re-hide the content in `prepare` and animate it into view, or return
    /// without animating and leave the in-app visible immediately.
    private let animationListener: (@MainActor (InAppAnimator) -> Void)?

    /// Callback invoked once after the in-app becomes visible.
    private let onShown: (() -> Void)?

    /// Callback invoked once after closing.
    private let onClose: (() -> Void)?

    /// Previous `WKUIDelegate` assigned to the hosted web view.
    private weak var previousUIDelegate: WKUIDelegate?

    /// View that physically hosts the slide-up container.
    private weak var slideHostView: UIView?

    /// Transparent overlay window used when the presenter is SwiftUI-based.
    private var slideOverlayWindow: UIWindow?

    /// Prevents duplicate close callbacks.
    private var didClose = false

    /// Prevents duplicate web view cleanup.
    private var didDestroyWebView = false

    /// Prevents duplicate SHOW event and shown callbacks.
    private var didShow = false

    /// Indicates that page loading and static resource injection completed.
    private var isPageLoaded = false

    /// Indicates that JavaScript has sent `.ready`.
    private var isJavaScriptReady = false

    /// Last insets sent to JavaScript.
    private var lastSentInsets: UIEdgeInsets?

    /// Work item used to fall back when `slideReady` is not received.
    private var slideReadyFallbackWorkItem: DispatchWorkItem?

    /// Work item used to force web view visibility when the animation
    /// block never reveals the content.
    private var visibilityWatchdogWorkItem: DispatchWorkItem?

    /// Slide layout received before protected insets are delivered.
    private var pendingSlideReadyPayload: InAppEventProcessing.SlideReadyPayload?

    /// Indicates whether the current container displays slide-up content.
    var isSlideUp: Bool {
        displayType == .slideUp
    }

    /// Creates an in-app container.
    ///
    /// - Parameters:
    ///   - webView: Web view displaying in-app content.
    ///   - companyId: Campaign identifier.
    ///   - smid: Send Message ID associated with the current in-app message.
    ///   - displayType: Native display type resolved from backend content.
    ///   - animationListener: Animation block captured from the host
    ///     application, invoked synchronously during reveal, or `nil`.
    ///   - onShown: Callback invoked once after the in-app becomes visible.
    ///   - onClose: Callback invoked once after closing.
    init(
        webView: WKWebView,
        companyId: Int,
        smid: String,
        displayType: InAppDisplayType,
        animationListener: (@MainActor (InAppAnimator) -> Void)? = nil,
        onShown: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.hostedWebView = webView
        self.companyId = companyId
        self.smid = smid
        self.displayType = displayType
        self.animationListener = animationListener
        self.onShown = onShown
        self.onClose = onClose

        super.init(nibName: nil, bundle: nil)

        modalPresentationCapturesStatusBarAppearance = true
    }

    /// Unsupported initializer — this view controller is not loaded from a storyboard.
    required init?(coder: NSCoder) {
        nil
    }

    /// Keeps the status bar visible while the in-app is displayed.
    override var prefersStatusBarHidden: Bool {
        false
    }

    /// Adds the hosted web view and pins it to all edges of the root view.
    ///
    /// The web view starts with alpha `0`. For slide-up content, resizing the
    /// controller's root view automatically resizes the web view because it is
    /// constrained to all four root-view edges.
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        previousUIDelegate = hostedWebView.uiDelegate
        hostedWebView.uiDelegate = self

        hostedWebView.alpha = 0
        hostedWebView.backgroundColor = .clear
        hostedWebView.isOpaque = false
        hostedWebView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(hostedWebView)

        NSLayoutConstraint.activate([
            hostedWebView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor
            ),
            hostedWebView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor
            ),
            hostedWebView.topAnchor.constraint(
                equalTo: view.topAnchor
            ),
            hostedWebView.bottomAnchor.constraint(
                equalTo: view.bottomAnchor
            )
        ])
    }

    /// Stores the view and optional window that host slide-up content.
    ///
    /// - Parameters:
    ///   - view: View whose bounds and safe-area insets define slide layout.
    ///   - overlayWindow: Overlay window retained for SwiftUI presentation.
    func configureSlideHost(
        view: UIView,
        overlayWindow: UIWindow?
    ) {
        slideHostView = view
        slideOverlayWindow = overlayWindow
    }

    /// Effective view used for slide-up geometry and safe-area calculations.
    private var effectiveSlideHostView: UIView? {
        slideHostView ?? parent?.view
    }

    /// Marks page loading and static resource injection as completed.
    ///
    /// Starts the fallback timer for all display types. For slide-up content
    /// the container is resized by `slideReady` before reveal. For regular
    /// content the container remains fullscreen. In both cases the web view
    /// stays invisible until `slideReady` or the fallback timer fires.
    func markPageLoaded() {
        guard !isPageLoaded else {
            return
        }

        isPageLoaded = true

        if isJavaScriptReady {
            sendProtectedInsetsToJavaScript()
        }

        scheduleSlideReadyFallback()
    }

    /// Called when JavaScript sends `.ready`.
    ///
    /// For all display types the container remains invisible until
    /// `slideReady` is received. This method only sends protected insets
    /// so the JavaScript can apply the campaign's final layout.
    func markJavaScriptReadyAndSendInsets() {
        isJavaScriptReady = true

        guard isPageLoaded else {
            return
        }

        sendProtectedInsetsToJavaScript()
    }

    /// Applies slide layout received from JavaScript.
    ///
    /// The payload may arrive before the page is loaded or before protected
    /// insets are delivered. In that case it is stored and applied later.
    ///
    /// - Parameter payload: Slide layout payload received from JavaScript.
    func applySlideReady(
        _ payload: InAppEventProcessing.SlideReadyPayload
    ) {
        guard !didShow else {
            return
        }

        pendingSlideReadyPayload = payload
        tryShowPendingSlide()
    }

    /// Sends updated safe-area insets after regular fullscreen layout changes.
    ///
    /// Layout updates do not trigger another reveal.
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard displayType != .slideUp else {
            return
        }

        sendProtectedInsetsToJavaScript()
    }

    /// Sends updated safe-area insets when UIKit reports safe-area changes.
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        guard displayType != .slideUp else {
            return
        }

        sendProtectedInsetsToJavaScript()
    }

    /// Closes In-App when the screen orientation changes.
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(
            to: size,
            with: coordinator
        )

        close()
    }

    /// Handles JavaScript `alert(...)` calls from the hosted web view.
    ///
    /// - Parameters:
    ///   - webView: Web view that requested the alert.
    ///   - message: Alert message from JavaScript.
    ///   - frame: Frame that requested the alert.
    ///   - completionHandler: Completion handler called after closing the alert.
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor () -> Void
    ) {
        let alertController = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            ) { _ in
                completionHandler()
            }
        )

        present(alertController, animated: true)
    }

    /// Cleans up an In-App after it disappears.
    ///
    /// Cleanup runs only when the container is really going away:
    /// - modal dismissal (`isBeingDismissed`) or child removal
    ///   (`isMovingFromParent`);
    /// - teardown of the hosting hierarchy without dismissal
    ///   (`view.window == nil` while nothing is presented from the
    ///   container), e.g. the host app replacing its root controller or the
    ///   host screen being popped.
    ///
    /// The detached check covers both presentation styles: a modally
    /// presented container has no parent, and an embedded slide-up container
    /// is destroyed together with its host screen. Without the detached
    /// branch a host-hierarchy teardown would destroy the container without
    /// `onClose`, leaving the awaiting presentation continuation — and the
    /// presentation queue slot — hanging forever.
    ///
    /// Temporary disappearances keep the In-App alive: the container's own
    /// `UIAlertController` presented for JavaScript `alert(...)`, or any
    /// other overlay covering the In-App without dismissing it.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        let isRealDismiss = isBeingDismissed || isMovingFromParent
        let isDetached = view.window == nil && presentedViewController == nil

        guard isRealDismiss || isDetached else {
            return
        }

        slideReadyFallbackWorkItem?.cancel()

        if parent != nil {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()
        }

        destroyWebView()
        releaseSlideOverlayWindow()
        closeOnce()
    }

    /// Closes the current In-App container.
    ///
    /// Embedded slide-up containers are removed from their parent hierarchy.
    /// Modally presented containers are dismissed normally.
    func close() {
        guard !didClose else {
            return
        }

        slideReadyFallbackWorkItem?.cancel()
        slideReadyFallbackWorkItem = nil

        if parent != nil {
            willMove(toParent: nil)
            view.removeFromSuperview()
            removeFromParent()

            destroyWebView()
            releaseSlideOverlayWindow()
            closeOnce()
            return
        }

        dismiss(animated: true)
    }

    /// Applies a pending layout after protected insets were delivered.
    ///
    /// For [InAppDisplayType.slideUp] the container is resized and positioned
    /// from the payload before revealing. For all other display types the
    /// container is revealed without resizing.
    private func tryShowPendingSlide() {
        guard !didShow else {
            return
        }

        guard lastSentInsets != nil else {
            return
        }

        guard let payload = pendingSlideReadyPayload else {
            return
        }

        slideReadyFallbackWorkItem?.cancel()
        slideReadyFallbackWorkItem = nil
        pendingSlideReadyPayload = nil

        if displayType == .slideUp, let hostView = effectiveSlideHostView {
            hostView.layoutIfNeeded()

            let hostBounds = hostView.bounds

            let height = min(
                max(payload.height, 1),
                max(hostBounds.height, 1)
            )

            let originY: CGFloat

            switch payload.position {
            case .top:
                originY = max(payload.paddingTop, 0)

            case .bottom:
                originY = max(
                    hostBounds.height
                        - payload.paddingBottom
                        - height,
                    0
                )
            }

            let targetFrame = CGRect(
                x: 0,
                y: originY,
                width: hostBounds.width,
                height: height
            )

            view.autoresizingMask = [.flexibleWidth]
            view.frame = targetFrame

            view.setNeedsLayout()
            view.layoutIfNeeded()
        }

        revealAndNotifyShown()
    }

    /// Starts fallback timer for in-app layout.
    ///
    /// If JavaScript does not send `slideReady` within one second, the root view
    /// remains fullscreen and becomes visible. This prevents an indefinitely
    /// invisible In-App for all display types.
    private func scheduleSlideReadyFallback() {
        slideReadyFallbackWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            guard !self.didShow else {
                return
            }

            self.pendingSlideReadyPayload = nil
            self.restoreFullscreenFrame()

            if self.isJavaScriptReady {
                self.sendProtectedInsetsToJavaScript()
            }

            self.revealAndNotifyShown()
        }

        slideReadyFallbackWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.slideReadyFallbackDelay,
            execute: workItem
        )
    }

    /// Restores fullscreen frame used by the slide-up fallback path.
    private func restoreFullscreenFrame() {
        guard let hostView = effectiveSlideHostView else {
            return
        }

        view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        view.frame = hostView.bounds
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    /// Sends protected top and bottom safe-area insets to JavaScript.
    ///
    /// JavaScript receives `native-event` with detail:
    /// `{ type: 'fringeSize', data: [top, bottom] }`.
    ///
    private func sendProtectedInsetsToJavaScript() {
        guard isPageLoaded else {
            return
        }

        guard isJavaScriptReady else {
            return
        }

        guard !didDestroyWebView else {
            return
        }

        view.layoutIfNeeded()

        let insets: UIEdgeInsets

        if displayType == .slideUp,
           let hostView = effectiveSlideHostView {
            insets = hostView.safeAreaInsets
        } else {
            insets = view.safeAreaInsets
        }

        if lastSentInsets == insets {
            return
        }

        lastSentInsets = insets

        let topInsetCssPx = Int(insets.top.rounded())
        let bottomInsetCssPx = Int(insets.bottom.rounded())

        let script = """
        window.dispatchEvent(new CustomEvent('native-event', {
            detail: {
                type: 'fringeSize',
                data: [\(topInsetCssPx), \(bottomInsetCssPx)]
            }
        }));
        """

        hostedWebView.evaluateJavaScript(script)

        // Insets are now delivered: a slide layout that arrived earlier can
        // be applied; without this re-check a payload received before the
        // insets would sit until the fallback timer dropped it and the
        // campaign fell back to fullscreen.
        tryShowPendingSlide()
    }

    /// Reveals the web view and sends SHOW callbacks exactly once.
    ///
    /// The web view is made visible first — the SDK guarantees the in-app
    /// becomes visible even when the animation block ignores this campaign,
    /// mirroring the Android SDK where the dialog is revealed before the
    /// shown listener runs.
    ///
    /// The show event is dispatched first; the animation listener is then
    /// invoked synchronously on the same main-actor pass. Because the reveal
    /// and the listener's `prepare` share one run-loop pass, Core Animation
    /// commits both as a single transaction: the first rendered frame
    /// already carries the prepared state, so no flash of unanimated
    /// content occurs.
    ///
    /// A registered listener may re-hide the web view in `prepare` and
    /// animate it into view. A block that returns without animating leaves
    /// the in-app immediately visible. A visibility watchdog covers a block
    /// that hides the content and never animates it back.
    private func revealAndNotifyShown() {
        guard !didShow else {
            return
        }

        didShow = true

        view.isUserInteractionEnabled = true
        hostedWebView.alpha = 1

        Task {
            await InAppEventProcess.shared.createInAppEvent(
                smid: smid,
                type: .show,
                data: nil
            )
        }

        if let animationListener {
            animationListener(
                InAppAnimatorImpl(
                    companyId: companyId,
                    view: hostedWebView
                )
            )

            scheduleVisibilityWatchdog()
        }

        onShown?()
    }

    /// Starts a safety timer that forces web view visibility.
    ///
    /// Covers host animation blocks that never reveal the web view (for
    /// example, `prepare` hides the content and `animate` is never called).
    /// The timer fires only when the web view is still fully invisible
    /// after `animationVisibilityTimeout`; a running animation that has
    /// already started changing alpha is never interrupted.
    private func scheduleVisibilityWatchdog() {
        visibilityWatchdogWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            guard !self.didDestroyWebView else {
                return
            }

            guard self.hostedWebView.alpha == 0 else {
                return
            }

            self.hostedWebView.alpha = 1
        }

        visibilityWatchdogWorkItem = workItem

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.animationVisibilityTimeout,
            execute: workItem
        )
    }

    /// Stops loading, detaches delegates and removes the web view.
    private func destroyWebView() {
        guard !didDestroyWebView else {
            return
        }

        didDestroyWebView = true

        visibilityWatchdogWorkItem?.cancel()
        visibilityWatchdogWorkItem = nil

        hostedWebView.stopLoading()
        hostedWebView.loadHTMLString("", baseURL: nil)
        hostedWebView.navigationDelegate = nil
        hostedWebView.uiDelegate = previousUIDelegate

        hostedWebView.configuration.userContentController.removeScriptMessageHandler(
            forName: InAppConstants.JSInterfaceName.inAppBridge
        )

        hostedWebView.removeFromSuperview()
    }

    /// Releases the transparent window used for SwiftUI slide-up content.
    private func releaseSlideOverlayWindow() {
        guard let slideOverlayWindow else {
            return
        }

        slideOverlayWindow.isHidden = true
        slideOverlayWindow.rootViewController = nil

        self.slideOverlayWindow = nil
        slideHostView = nil
    }

    /// Invokes close callback only once.
    private func closeOnce() {
        guard !didClose else {
            return
        }

        didClose = true
        onClose?()
    }
}
