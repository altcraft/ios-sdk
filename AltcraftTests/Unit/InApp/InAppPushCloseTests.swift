//
//  InAppPushCloseTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import WebKit
@testable import AltcraftInApp

/**
 * InAppPushCloseTests
 *
 * Verifies that a push notification tap closes all displayed in-app content.
 * Modules stay decoupled: the in-app module observes the push event by name
 * only and walks the controller trees of all windows.
 *
 * Positive scenarios:
 * - test_1: fullscreen modal in-app closes on push tap.
 * - test_2: embedded slide-up in-app is removed from its parent on push tap.
 *
 * Edge scenarios:
 * - test_3: push tap without displayed in-app is a no-op.
 * - test_4: observer registration is idempotent.
 */
@MainActor
final class InAppPushCloseTests: IsolatedTestCase {

    /// Number of times the container invoked its close callback.
    private var closeCount = 0

    // MARK: - Positive scenarios

    /// test_1: fullscreen modal in-app closes on push tap.
    func test_1_fullscreenInApp_closesOnPushTap() throws {
        InAppPushCloseObserver.register()

        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer(displayType: .fullscreen)
        root.present(container, animated: false)
        drainMainLoop()

        postPushTap()
        try waitUntil { self.closeCount == 1 }

        XCTAssertEqual(
            InAppPushCloseObserver.testReceivedCount,
            1,
            "Observer must receive exactly one push tap"
        )
        XCTAssertEqual(
            InAppPushCloseObserver.testScanCount,
            1,
            "Close-all scan must run on the main actor"
        )
        XCTAssertEqual(
            InAppPushCloseObserver.testClosedCount,
            1,
            "Container must be found and closed"
        )
        XCTAssertEqual(
            closeCount,
            1,
            "Push tap must close the fullscreen in-app exactly once"
        )
    }

    /// test_2: embedded slide-up in-app is removed from its parent on push tap.
    func test_2_embeddedSlideUp_isRemovedOnPushTap() throws {
        InAppPushCloseObserver.register()

        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer(displayType: .slideUp)
        root.addChild(container)
        root.view.addSubview(container.view)
        container.didMove(toParent: root)
        drainMainLoop()

        postPushTap()
        try waitUntil { self.closeCount == 1 }
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "Push tap must close the embedded slide-up in-app exactly once"
        )
        XCTAssertNil(
            container.parent,
            "Embedded in-app must be removed from its parent"
        )
    }

    // MARK: - Edge scenarios

    /// test_3: push tap without displayed in-app is a no-op.
    func test_3_pushTapWithoutInApp_isNoOp() throws {
        InAppPushCloseObserver.register()

        let (window, root) = makeWindow()
        defer { window.isHidden = true }
        _ = root

        postPushTap()
        drainMainLoop()

        XCTAssertEqual(closeCount, 0, "No in-app must be closed")
    }

    /// test_4: observer registration is idempotent.
    func test_4_observerRegistration_isIdempotent() throws {
        InAppPushCloseObserver.register()
        InAppPushCloseObserver.register()

        let (window, root) = makeWindow()
        defer { window.isHidden = true }

        let container = makeContainer(displayType: .fullscreen)
        root.present(container, animated: false)
        drainMainLoop()

        postPushTap()
        try waitUntil { self.closeCount == 1 }
        drainMainLoop()

        XCTAssertEqual(
            closeCount,
            1,
            "A duplicated registration must not close the in-app twice"
        )
    }

    // MARK: - Helpers

    /// Posts the push-tap notification by its cross-module name.
    private func postPushTap() {
        NotificationCenter.default.post(
            name: Notification.Name(
                InAppConstants.NotificationCenter.pushDidReceive
            ),
            object: nil
        )
    }

    /// Creates a visible window with an empty root controller.
    ///
    /// The window is attached to the foreground scene so that scene-based
    /// window enumeration (used by the SDK) can see it.
    private func makeWindow() -> (UIWindow, UIViewController) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first

        let bounds = scene?.coordinateSpace.bounds ?? UIScreen.main.bounds
        let window: UIWindow

        if let scene {
            window = UIWindow(windowScene: scene)
            window.frame = bounds
        } else {
            window = UIWindow(frame: bounds)
        }

        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        return (window, root)
    }

    /// Creates an in-app container counting close callbacks.
    private func makeContainer(
        displayType: InAppDisplayType
    ) -> InAppContainerViewController {
        closeCount = 0

        let webView = WKWebView(frame: .zero)

        return InAppContainerViewController(
            webView: webView,
            companyId: 1,
            smid: "push-close-test-smid",
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
