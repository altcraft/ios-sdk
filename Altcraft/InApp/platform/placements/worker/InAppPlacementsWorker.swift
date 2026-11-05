//
//  InAppPlacementsWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Queue worker of the in-app placements feature.
///
/// Owns the in-app placements processing pipeline: fetches and applies fresh
/// placements from the backend when auto-request is enabled.
@available(iOSApplicationExtension, unavailable)
actor InAppPlacementsWorker {

    /// Shared instance.
    static let shared = InAppPlacementsWorker()

    private init() {}

    /// Starts the in-app placements processing pipeline.
    ///
    /// - Parameter enableRetry: If `true`, schedules internal retry on failure.
    func processPending(enableRetry: Bool = true) async {
        await InAppPlacementsProcess.shared.requestPlacements(
            enableRetry: enableRetry
        )
    }
}
