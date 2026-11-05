//
//  InAppStaticWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Worker of the in-app static resources feature.
///
/// Owns access to the cached/network in-app static bundle used by the
/// presentation layer.
@available(iOSApplicationExtension, unavailable)
actor InAppStaticWorker {

    /// Shared instance.
    static let shared = InAppStaticWorker()

    private init() {}

    /// Returns the available in-app static bundle.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on failure.
    /// - Returns: Available static bundle, or `nil` if unavailable.
    func getInAppStatic(
        enableRetry: Bool = true
    ) async -> InAppModel.InAppStaticProcess? {
        await InAppStaticProcess.shared.getInAppStatic(
            enableRetry: enableRetry
        )
    }
}
