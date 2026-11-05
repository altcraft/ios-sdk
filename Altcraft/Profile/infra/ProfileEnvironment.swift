//
//  ProfileEnvironment.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Provides dependencies required by the Profile module.
///
/// Shared SDK data is requested through `CoreEnvironmentProvider`.
struct ProfileEnvironment {

    /// Returns a freshly created profile environment for an operation.
    ///
    /// Each call produces an independent (uncached) environment.
    static func fresh() -> ProfileEnvironment {
        ProfileEnvironment()
    }

    private init() {}

    /// Throws if the Core or Profile module Core Data is in critical error state.
    ///
    /// The Profile module's failure is isolated: it limits only profile
    /// operations, the Core flag additionally covers Core's shared data.
    func checkCoreDataError() throws {
        try CoreEnvironmentProvider.checkDbError(
            module: ProfileConstants.CoreData.modelName
        )
    }

    /// Returns the current user tag.
    ///
    /// - Returns: Current user tag.
    func userTag() async throws -> String {
        try await CoreEnvironmentProvider.userTag()
    }
}
