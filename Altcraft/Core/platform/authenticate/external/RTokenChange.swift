//
//  RTokenChange.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Handles role token (rToken) changes.
///
/// Compares the current role token with the previously saved one and notifies
/// the SDK modules about the change. The role token is checked at two points:
/// - after the SDK configuration is installed (``checkFromInit()``);
/// - every time a JWT is read for authentication (``checkFromJWT(jwt:)``).
///
/// The SDK initialization dispatch additionally re-runs ``checkFromInit()``
/// at the dispatch point and tracks delivered notifications through
/// ``notificationCount``: a change detected by a JWT read while the module
/// initialization phase is already running settles with the dispatch, and the
/// phase is re-run once so its data processing happens against the new
/// identity (see ``waitUntilSettled()``).
///
/// Semantics (Android parity, `RTokenChange`):
/// - a `nil` token is ignored: it is neither saved nor notified;
/// - an unchanged token is ignored;
/// - when a previously saved token exists and the new token differs, all
///   registered modules are notified and the new token is saved;
/// - the first saved token does not trigger the notification.
///
/// The saved token is kept independently of the SDK configuration, so it
/// survives a transition to a `nil` configuration token: a later restoration
/// with a different token is still detected and reported to the modules.
actor RTokenChange {

    /// Shared instance.
    static let shared = RTokenChange()

    /// Whether a change notification is currently being delivered.
    private var notifyInFlight = false

    /// Monotonic count of delivered role-token change notifications.
    ///
    /// Lets the SDK initialization dispatch detect a change that was
    /// delivered while the module initialization phase was already running:
    /// a snapshot read before the phase compared with the count after it
    /// (``hasChanged(since:)``) reports whether the phase raced with a
    /// change notification and must be re-run.
    private(set) var notificationCount = 0

    /// Continuations waiting until the in-flight change notification has
    /// settled.
    private var settleWaiters: [CheckedContinuation<Void, Never>] = []

    private init() {}

    /// Suspends until no role-token change notification is in progress.
    ///
    /// The SDK initialization dispatch awaits this before notifying modules
    /// that the SDK is initialized, so a role-token change detected just
    /// before the dispatch completes its module notification (data wipe and
    /// follow-up requests) before module initialization runs. JWT reads
    /// await the check inline (Android parity, `AuthManager.jwtReader`), so
    /// in practice the notification completes inside the flow that read the-
    /// JWT; the wait covers a notification started by a concurrent flow.
    ///
    /// The dispatch also awaits this after the module initialization phase:
    /// a change detected by a JWT read while the phase was running (the JWT
    /// became available mid-dispatch) settles there, and the phase is re-run
    /// once against the new identity.
    func waitUntilSettled() async {
        guard notifyInFlight else {
            return
        }

        await withCheckedContinuation { continuation in
            settleWaiters.append(continuation)
        }
    }

    /// Returns whether at least one change notification completed since
    /// `count` was read.
    ///
    /// Used by the SDK initialization dispatch to detect a role-token change
    /// delivered while the module initialization phase was running.
    ///
    /// - Parameter count: Previously read ``notificationCount`` snapshot.
    /// - Returns: `true` if the count has grown since the snapshot.
    func hasChanged(since count: Int) -> Bool {
        notificationCount > count
    }

    /// Resumes waiters when no notification is in progress.
    private func resumeSettledWaiters() {
        guard !notifyInFlight else {
            return
        }

        let waiters = settleWaiters
        settleWaiters.removeAll(keepingCapacity: true)
        waiters.forEach { $0.resume() }
    }

    /// Checks for a role token change after the SDK configuration is installed.
    ///
    /// The checked value is the configuration rToken, or the rToken extracted
    /// from the JWT payload when the configuration defines none.
    func checkFromInit() async {
        let config = try? await Environment.create().config()

        await check(
            newToken: config?.rToken ?? extractRToken(
                jwt: JWTManager.shared.getJWT()
            )
        )
    }

    /// Checks for a role token change in a JWT.
    ///
    /// - Parameter jwt: JWT token, may be `nil`.
    func checkFromJWT(jwt: String?) async {
        await check(
            newToken: extractRToken(jwt: jwt)
        )
    }

    /// Removes the saved role token.
    ///
    /// Called on SDK clear, mirroring Android
    /// `ModuleLifecycle.onSdkClear` → `Preferences.clearCurrentRToken`.
    func clear() {
        StoredVariablesManager.shared.setCurrentRToken(
            value: nil
        )
    }

    /// Compares the role token with the previously saved one.
    ///
    /// Notifies the SDK modules about the change and saves the new token.
    /// The token is saved before the notification: the read–compare–save
    /// sequence contains no suspension point, so concurrent checks observe
    /// the fresh value and a burst of JWT reads collapses into a single
    /// change cycle (Android parity, the `checkRTokenChanged` mutex section
    /// covering both the notification and the save).
    ///
    /// The notification is tracked with ``notifyInFlight`` so
    /// ``waitUntilSettled()`` can wait for its completion.
    ///
    /// - Parameter newToken: New role token, may be `nil`.
    private func check(newToken: String?) async {
        guard let newToken else {
            return
        }

        let oldToken = StoredVariablesManager.shared.getCurrentRToken()

        guard oldToken != newToken else { return }

        // Saved synchronously before the awaited notification: no reentrancy
        // window between reading and saving.
        StoredVariablesManager.shared.setCurrentRToken(value: newToken)

        if oldToken != nil {
            notifyInFlight = true

            await ModuleRegistry.shared.notifyRTokenChanged()

            notificationCount += 1

            notifyInFlight = false
            resumeSettledWaiters()
        }
    }
}
