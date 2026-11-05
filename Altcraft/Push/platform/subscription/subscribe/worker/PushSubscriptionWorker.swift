//
//  PushSubscriptionWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the push subscription feature.
///
/// Owns the subscription processing pipeline: enqueues subscription runs into
/// the serial start queue so only one run is active at a time.
@available(iOSApplicationExtension, unavailable)
actor PushSubscriptionWorker {

    /// Shared instance.
    static let shared = PushSubscriptionWorker()

    private init() {}

    /// Starts the subscription processing pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPending(enableRetry: Bool = true) async {
        await PushSubscriptionProcess.shared.enqueueStart(
            enableRetry: enableRetry
        )
    }
}
