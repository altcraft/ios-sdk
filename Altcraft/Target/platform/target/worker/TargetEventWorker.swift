//
//  TargetEventWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the target (mobile events) feature.
///
/// Owns the mobile event processing pipeline.
actor TargetEventWorker {

    /// Shared instance.
    static let shared = TargetEventWorker()

    private init() {}

    /// Starts the mobile event processing pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPending(enableRetry: Bool = true) async {
        await TargetEventProcess.shared.enqueueStart(
            enableRetry: enableRetry
        )
    }
}
