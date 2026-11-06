//
//  ProfileUpdateWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the profile update feature.
///
/// Owns the profile update processing pipeline.
actor ProfileUpdateWorker {

    /// Shared instance.
    static let shared = ProfileUpdateWorker()

    private init() {}

    /// Starts the profile update processing pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPending(enableRetry: Bool = true) async {
        await ProfileUpdateProcess.shared.enqueueStart(
            enableRetry: enableRetry
        )
    }

    /// Starts the profile update processing pipeline awaiting its completion
    /// (background refresh path: the app may be suspended right after the
    /// system task is marked complete).
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPendingAwaited(enableRetry: Bool) async {
        await ProfileUpdateProcess.shared.enqueueStart(
            enableRetry: enableRetry,
            awaitCompletion: true
        )
    }
}
