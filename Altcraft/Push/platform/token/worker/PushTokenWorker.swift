//
//  PushTokenWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the push token feature.
///
/// Owns the device token update pipeline used by initialization and by other
/// push features before they send requests.
@available(iOSApplicationExtension, unavailable)
actor PushTokenWorker {

    /// Shared instance.
    static let shared = PushTokenWorker()

    private init() {}

    /// Runs the device token update pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on retryable failure.
    /// - Returns: `true` when the update is not needed or finishes without a
    ///   retry event, otherwise `false`.
    @discardableResult
    func processPending(enableRetry: Bool = true) async -> Bool {
        await PushTokenProcess.shared.tokenUpdate(
            enableRetry: enableRetry
        )
    }

    /// Runs the device token update pipeline awaiting its completion
    /// (background refresh path: the app may be suspended right after the
    /// system task is marked complete).
    ///
    /// An offline snapshot skips the attempt: an offline send would fail and
    /// be dropped without retry, so the token stays unsaved for the next pass.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on retryable failure.
    func processPendingAwaited(enableRetry: Bool) async {
        guard await NetworkMonitor.shared.isOnline() else { return }
        await processPending(enableRetry: enableRetry)
    }
}
