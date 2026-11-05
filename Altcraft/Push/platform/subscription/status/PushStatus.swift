//
//  PushStatus.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Handles subscription status requests for Push and In-App APIs.
internal final class PushStatusProcess: @unchecked Sendable {

    /// Shared singleton instance.
    static let shared = PushStatusProcess()

    /// Prevents external instances.
    private init() {}

    /// Requests the status of the latest push subscription in profile.
    ///
    /// - Returns: Response with HTTP status code, or `nil` if request preparation or execution fails.
    func getStatusOfLatestSubscription() async ->
    ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >? {
        guard let source = await getPushStatusRequestData() else {
            PushLog.error(
                #function,
                error: PushModuleEvents.pushStatusRequestDataIsNil
            )
            return nil
        }

        let data = RequestModel.PushStatusRequestData(
            path: source.path,
            requestId: source.requestId,
            provider: nil,
            token: nil
        )

        return await sendPushStatusRequest(data: data)
    }

    /// Requests the status of the push subscription matching the current token and provider.
    ///
    /// - Returns: Response with HTTP status code, or `nil` if request preparation or execution fails.
    func getStatusForCurrentSubscription() async ->
    ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >? {
        guard let source = await getPushStatusRequestData() else {
            PushLog.error(
                #function,
                error: PushModuleEvents.pushStatusRequestDataIsNil
            )
            return nil
        }

        let data = RequestModel.PushStatusRequestData(
            path: source.path,
            requestId: source.requestId,
            provider: source.provider,
            token: source.token
        )

        return await sendPushStatusRequest(data: data)
    }

    /// Requests the status of the latest push subscription for a specific provider.
    ///
    /// - Parameter provider: Optional push provider override.
    /// - Returns: Response with HTTP status code, or `nil` if request preparation or execution fails.
    func getStatusOfLatestSubscriptionForProvider(
        provider: String? = nil
    ) async -> ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >? {
        if let provider, !TokenManager.shared.validProviders.contains(provider) {
            PushLog.error(
                #function,
                error: PushModuleEvents.invalidPushProvider
            )
            return nil
        }

        guard let source = await getPushStatusRequestData() else {
            PushLog.error(
                #function,
                error: PushModuleEvents.pushStatusRequestDataIsNil
            )
            return nil
        }

        let data = RequestModel.PushStatusRequestData(
            path: source.path,
            requestId: source.requestId,
            provider: provider ?? source.provider,
            token: nil
        )

        return await sendPushStatusRequest(data: data)
    }

    /// Sends a prepared push status request.
    ///
    /// - Parameter data: Push status request data.
    /// - Returns: Response with HTTP status code, or `nil` if request creation fails.
    private func sendPushStatusRequest(
        data: RequestModel.PushStatusRequestData
    ) async -> ResponseModel.ResponseWithHttpCode<
        ResponseModel.ResponseWithProfile
    >? {
        guard let request = await pushStatusRequest(data: data) else {
            PushLog.error(
                #function,
                error: CoreEvents.failedCreateRequest
            )
            return nil
        }

        let result = await RequestManager.shared.sendRequest(
            request: request,
            requestData: data
        )

        return ResponseModel.ResponseWithHttpCode(
            httpCode: result.httpCode,
            response: result.response
        )
    }
}

/// Builds `PushStatusRequestData` used for push subscription status requests.
///
/// Uses the saved token when available, otherwise falls back to the current
/// token returned by the active push provider.
///
/// - Returns: Valid push status request data, or `nil` on failure.
func getPushStatusRequestData() async -> RequestModel.PushStatusRequestData? {
    let env = PushEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let savedToken = PushStoredVariables.shared.getSavedToken()
        let currentToken = try? await env.currentToken()
        let tokenData = savedToken ?? currentToken

        return RequestModel.PushStatusRequestData(
            path: PushConstants.UrlPath.status,
            requestId: UUID().uuidString,
            provider: tokenData?.provider,
            token: tokenData?.token
        )
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

