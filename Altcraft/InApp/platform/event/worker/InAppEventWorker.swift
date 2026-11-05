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
}
