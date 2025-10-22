//
//  ForegroundCheck.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import UIKit

/// A tiny helper that fires a single callback when the app is in the foreground.
/// Works on iOS 12+; scene-aware on iOS 13+. Calls the handler on the main queue.
public final class ForegroundCheck {

    /// Shared singleton instance.
    public static let shared = ForegroundCheck()

    private init() {}

    /// Invokes `handler` exactly once when the app becomes foreground/active.
    /// If the app is already in the foreground, the handler is invoked immediately.
    /// - Parameter handler: Closure to run once the app is in the foreground.
    public func isForeground(_ handler: @escaping () -> Void) {
        #if APP_EXTENSION
        return
        #else
        let call = { DispatchQueue.main.async { handler() } }

        if Thread.isMainThread {
            if Self.isForegroundMain() { call(); return }
        } else {
            var fg = false
            DispatchQueue.main.sync { fg = Self.isForegroundMain() }
            if fg { call(); return }
        }

        let center = NotificationCenter.default
        var tokens = [NSObjectProtocol]()

        let fire: () -> Void = {
            for t in tokens { center.removeObserver(t) }
            tokens.removeAll()
            call()
        }

        tokens.append(center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in fire() })

        if #available(iOS 13.0, *) {
            tokens.append(center.addObserver(
                forName: UIScene.didActivateNotification,
                object: nil, queue: .main
            ) { _ in fire() })
        }
        #endif
    }

    /// Returns `true` if the app is currently in the foreground, otherwise `false`.
    /// Safe to call from any thread and in background tasks.
    public func isForegroundNow() -> Bool {
        #if APP_EXTENSION
        return false
        #else
        if Thread.isMainThread {
            return Self.isForegroundMain()
        } else {
            var fg = false
            DispatchQueue.main.sync {
                fg = Self.isForegroundMain()
            }
            return fg
        }
        #endif
    }

    /// Main-thread only: foreground check for iOS 12 and 13+ with scenes.
    @inline(__always)
    private static func isForegroundMain() -> Bool {
        if #available(iOS 13.0, *) {
            // Scenes may be empty during BGTask, return false safely
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .contains { $0.activationState == .foregroundActive }
        } else {
            return UIApplication.shared.applicationState == .active
        }
    }
}


