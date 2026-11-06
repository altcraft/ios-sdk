//
//  InAppEventWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the in-app event feature.
///
/// Owns the in-app event delivery pipeline.
@available(iOSApplicationExtension, unavailable)
actor InAppEventWorker {

    /// Shared instance.
    static let shared = InAppEventWorker()

    private init() {}

    /// Flushes all pending in-app events.
    func processPending() async {
        await InAppEventProcess.shared.sendAllInAppEvents()
    }

    /// Flushes all pending in-app events awaiting completion (background
    /// refresh path).
    ///
    /// An offline snapshot skips the attempt: an offline send would fail and
    /// be dropped without retry, so the events stay stored for the next pass.
    ///
    /// - Parameter enableRetry: Unused; the batch send never schedules
    ///   internal retries.
    func processPendingAwaited(enableRetry: Bool) async {
        guard await NetworkMonitor.shared.isOnline() else { return }
        await processPending()
    }
}
