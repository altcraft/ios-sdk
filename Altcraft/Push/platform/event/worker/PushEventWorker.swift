//
//  PushEventWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the push event feature.
///
/// Owns the push event delivery pipeline: flushes all pending push events in
/// order from local storage.
@available(iOSApplicationExtension, unavailable)
actor PushEventWorker {

    /// Shared instance.
    static let shared = PushEventWorker()

    private init() {}

    /// Flushes all pending push events.
    func processPending() async {
        await PushEventProcess.shared.sendAllPushEvents()
    }

    /// Flushes all pending push events awaiting completion (background
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
