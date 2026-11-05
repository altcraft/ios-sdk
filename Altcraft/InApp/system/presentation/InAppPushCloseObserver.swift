//
//  InAppPushCloseObserver.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
import UIKit

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Closes displayed in-app content when the user taps a push notification.
///
/// The push and in-app modules must not know about each other, so this
/// observer listens to the push module's `NotificationCenter` event by name
/// only (`InAppConstants.NotificationCenter.pushDidReceive`). The push
/// module posts the event before any click processing starts, so the
/// in-app begins closing before the host app navigates.
///
/// Every displayed in-app container is closed: fullscreen modals found in
/// the presented controller chain and slide-up containers embedded in any
/// window hierarchy, including the SwiftUI overlay window.
@available(iOSApplicationExtension, unavailable)
@MainActor
internal enum InAppPushCloseObserver {

    /// Registration token of the push-tap observer.
    private static var token: NSObjectProtocol?

    #if DEBUG
    /// Test diagnostics (main thread only): push-tap notifications received.
    nonisolated(unsafe) internal static var testReceivedCount = 0

    /// Test diagnostics (main thread only): all-windows scans executed.
    nonisolated(unsafe) internal static var testScanCount = 0

    /// Test diagnostics (main thread only): containers closed.
    nonisolated(unsafe) internal static var testClosedCount = 0
    #endif

    /// Subscribes to push-tap notifications once.
    ///
    /// Registration is idempotent: repeated calls (e.g. repeated SDK
    /// initialization) do not duplicate the observer.
    static func register() {
        guard token == nil else {
            return
        }

        token = NotificationCenter.default.addObserver(
            forName: Notification.Name(
                InAppConstants.NotificationCenter.pushDidReceive
            ),
            object: nil,
            queue: .main
        ) { _ in
            #if DEBUG
            InAppPushCloseObserver.testReceivedCount += 1
            #endif
            Task { @MainActor in
                closeAllDisplayed()
            }
        }
    }

    /// Closes every displayed in-app container in all window scenes.
    private static func closeAllDisplayed() {
        #if DEBUG
        testScanCount += 1
        #endif

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }

        for window in windows {
            guard let root = window.rootViewController else {
                continue
            }

            closeInAppContainers(from: root)
        }
    }

    /// Recursively closes in-app containers found in the controller tree.
    ///
    /// Walks child and presented controllers so embedded slide-up content
    /// and fullscreen modals are both covered.
    ///
    /// - Parameter controller: Controller to inspect together with its
    ///   descendants.
    private static func closeInAppContainers(
        from controller: UIViewController
    ) {
        if let container = controller.asInAppContainerViewController {
            #if DEBUG
            testClosedCount += 1
            #endif
            container.close()
            return
        }

        for child in controller.children {
            closeInAppContainers(from: child)
        }

        if let presented = controller.presentedViewController {
            closeInAppContainers(from: presented)
        }
    }
}
