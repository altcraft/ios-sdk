//
//  PushStatusWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Worker of the push subscription status feature.
///
/// Exposes the push subscription status queries used by the public API.
@available(iOSApplicationExtension, unavailable)
actor PushStatusWorker {

    /// Shared instance.
    static let shared = PushStatusWorker()

    private init() {}

    /// Requests the status of the latest push subscription.
    ///
    /// - Returns: Response with HTTP status code, or `nil` on failure.
    func getStatusOfLatestSubscription() async ->
        ResponseModel.ResponseWithHttpCode<
            ResponseModel.ResponseWithProfile
        >? {
        await PushStatusProcess.shared.getStatusOfLatestSubscription()
    }

    /// Requests the status of the push subscription matching the current
    /// token and provider.
    ///
    /// - Returns: Response with HTTP status code, or `nil` on failure.
    func getStatusForCurrentSubscription() async ->
        ResponseModel.ResponseWithHttpCode<
            ResponseModel.ResponseWithProfile
        >? {
        await PushStatusProcess.shared.getStatusForCurrentSubscription()
    }

    /// Requests the status of the latest push subscription for a provider.
    ///
    /// - Parameter provider: Optional push provider override.
    /// - Returns: Response with HTTP status code, or `nil` on failure.
    func getStatusOfLatestSubscriptionForProvider(
        provider: String? = nil
    ) async -> ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >? {
        await PushStatusProcess.shared.getStatusOfLatestSubscriptionForProvider(
            provider: provider
        )
    }
}
