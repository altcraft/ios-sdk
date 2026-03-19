//
//  ForegroundCheck.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import UIKit
import Foundation

/// Executes callbacks once the app becomes active (foreground) for the first time
/// during the current process lifetime.
///
/// Design:
/// - The type is isolated to the main actor because it reads UIApplication state
///   and subscribes to UI lifecycle notifications.
/// - A one-shot gate is used so multiple callers can await the same first activation.
/// - If the app is already active, the gate is opened immediately.
/// - Otherwise, the class waits for the first activation event and then opens the gate.
@available(iOSApplicationExtension, unavailable)
@MainActor
final class ForegroundCheck {
    static let shared = ForegroundCheck()

    /// One-shot gate opened after the first foreground activation.
    private let gate = OneShotGate()

    /// Strong reference to the activation observer.
    ///
    /// This is the key fix for the leaked continuation issue:
    /// the observer must stay alive until one of activation notifications arrives.
    private var activationObserver: FirstActivationObserver?

    private init() {
        if UIApplication.shared.applicationState == .active {
            Task { await gate.fire() }
            return
        }

        Task { @MainActor in
            await waitForFirstActivationEvent()
            await gate.fire()
        }
    }

    /// Executes `handler` after the first foreground activation.
    ///
    /// If activation already happened, `handler` runs immediately.
    ///
    /// - Parameter handler: Closure executed on the main actor.
    func isForeground(_ handler: @escaping @Sendable () -> Void) {
        Task { @MainActor in
            await gate.wait()
            handler()
        }
    }

    /// Suspends until the first foreground activation occurs.
    func waitUntilForeground() async {
        await gate.wait()
    }

    /// Waits for the first activation notification.
    ///
    /// Returns immediately if the application is already active.
    private func waitForFirstActivationEvent() async {
        if UIApplication.shared.applicationState == .active {
            return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            if UIApplication.shared.applicationState == .active {
                cont.resume()
                return
            }

            let observer = FirstActivationObserver(continuation: cont)

            observer.onFinish = { [weak self] in
                self?.activationObserver = nil
            }

            activationObserver = observer
            observer.start()
        }
    }
}

/// A one-shot synchronization gate.
///
/// Once fired:
/// - all current waiters are resumed
/// - all future waiters pass immediately
private actor OneShotGate {
    private var fired = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Opens the gate and resumes all waiting continuations.
    func fire() {
        guard !fired else { return }

        fired = true

        let currentWaiters = waiters
        waiters.removeAll()

        for waiter in currentWaiters {
            waiter.resume()
        }
    }

    /// Suspends until the gate is opened.
    func wait() async {
        if fired { return }

        await withCheckedContinuation { cont in
            if fired {
                cont.resume()
            } else {
                waiters.append(cont)
            }
        }
    }
}

/// Observes activation notifications and resumes a continuation exactly once.
///
/// Important:
/// - This object must be strongly retained while waiting.
/// - It removes all NotificationCenter subscriptions on completion.
/// - It resumes the continuation exactly once.
@MainActor
private final class FirstActivationObserver: NSObject {
    private var continuation: CheckedContinuation<Void, Never>?
    private var didFinish = false

    /// Called after completion so the owner can release its strong reference.
    var onFinish: (() -> Void)?

    /// Creates an observer that resumes the continuation on activation.
    ///
    /// - Parameter continuation: Continuation to resume.
    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
        super.init()
    }

    /// Starts observing activation notifications.
    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBecameActive),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Handles activation and resumes the continuation once.
    @objc private func handleBecameActive() {
        finishIfNeeded()
    }

    /// Finishes observation, removes subscriptions, resumes continuation once,
    /// and notifies the owner that the observer can be released.
    private func finishIfNeeded() {
        guard !didFinish else { return }
        didFinish = true

        NotificationCenter.default.removeObserver(self)

        continuation?.resume()
        continuation = nil

        onFinish?()
        onFinish = nil
    }
}
