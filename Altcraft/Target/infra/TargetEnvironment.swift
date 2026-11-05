//
//  TargetEnvironment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Provides dependencies required by the Target module.
///
/// Shared SDK data is requested through `CoreEnvironmentProvider`.
struct TargetEnvironment {

    /// Returns a freshly created target environment for an operation.
    ///
    /// Each call produces an independent (uncached) environment.
    static func fresh() -> TargetEnvironment {
        TargetEnvironment()
    }

    private init() {}

    /// Throws if the Core or Target module Core Data is in critical error state.
    ///
    /// The Target module's failure is isolated: it limits only target
    /// operations, the Core flag additionally covers Core's shared data.
    func checkCoreDataError() throws {
        try CoreEnvironmentProvider.checkDbError(
            module: TargetConstants.CoreData.modelName
        )
    }

    /// Returns the current user tag.
    ///
    /// - Returns: Current user tag.
    func userTag() async throws -> String {
        try await CoreEnvironmentProvider.userTag()
    }
}
