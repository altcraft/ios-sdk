//
//  InAppSubscriptionWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the in-app subscription feature.
///
/// Owns the in-app subscription processing pipeline.
@available(iOSApplicationExtension, unavailable)
actor InAppSubscriptionWorker {

    /// Shared instance.
    static let shared = InAppSubscriptionWorker()

    private init() {}

    /// Starts the in-app subscription processing pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPending(enableRetry: Bool = true) async {
        await InAppSubscriptionProcess.shared.enqueueStart(
            enableRetry: enableRetry
        )
    }

    /// Starts the in-app subscription processing pipeline awaiting its
    /// completion (background refresh path: the app may be suspended right
    /// after the system task is marked complete).
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPendingAwaited(enableRetry: Bool) async {
        await InAppSubscriptionProcess.shared.enqueueStart(
            enableRetry: enableRetry,
            awaitCompletion: true
        )
    }
}
