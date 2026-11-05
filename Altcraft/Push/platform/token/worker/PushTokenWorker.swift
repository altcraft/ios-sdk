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
}
