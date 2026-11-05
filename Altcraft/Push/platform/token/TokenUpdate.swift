//
//  TokenUpdate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// A singleton class responsible for handling device token updates for Altcraft profiles.
@available(iOSApplicationExtension, unavailable)
final actor PushTokenProcess {

    static let shared = PushTokenProcess()

    private let tokenManager = TokenManager.shared
    private let backgroundTask = AccessToBackground.shared
    private let userDefault = PushStoredVariables.shared

    var currentToken: TokenData?

    private let coordinator = UpdateCoordinator<Bool>()

    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    /// - Returns: Function name decorated with the token update scope.
    private func getFunc(_ name: String) -> String {
        "\(name) :: PushTokenProcess"
    }

    private init() {}

    /// Initiates the device push token update flow.
    ///
    /// A new request identifier is created only when a token update is required.
    /// The same identifier is passed to every retry attempt for this update.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on retryable failure.
    /// - Returns: `true` if update is not needed or finishes without a retry event,
    ///   otherwise `false`.
    func tokenUpdate(enableRetry: Bool = true) async -> Bool {
        await coordinator.run(operation: {
            await self.tokenUpdateCheck(
                enableRetry: enableRetry
            )
        })
    }

    /// Performs the device push token update pre-check flow.
    ///
    /// Creates one request identifier for the complete update operation and
    /// passes it through the initial request and every retry attempt.
    ///
    /// - Parameter enableRetry: If `true`, schedules retry on retryable failure.
    /// - Returns: `true` if update is not needed or finishes without a retry event,
    ///   otherwise `false`.
    fileprivate func tokenUpdateCheck(
        enableRetry: Bool
    ) async -> Bool {
        let env = PushEnvironment.fresh()
      
        do {
            let saved = PushStoredVariables.shared.getSavedToken()

            if saved == nil {
                return true
            }

            let current = try await env.currentToken()

            if saved?.token == current.token {
                return true
            }

            currentToken = current

            RetryCounters.shared.reset(
                PushConstants.RetryKey.tokenUpdate
            )
            
            return await tokenUpdateResult(
                enableRetry: enableRetry,
                requestId: UUID().uuidString
            )
        } catch {
            PushLog.error(#function, error: error)
            return false
        }
    }

    /// Handles the update outcome based on request result.
    ///
    /// Reuses the provided request identifier when a retry is scheduled.
    ///
    /// - Parameters:
    ///   - enableRetry: If `true`, schedules retry on retryable failure.
    ///   - requestId: Identifier shared by all attempts of the current update.
    /// - Returns: `false` for a retry event; `true` for any other event.
    func tokenUpdateResult(
        enableRetry: Bool,
        requestId: String
    ) async -> Bool {
        switch await request(requestId: requestId) {
        case is RetryEvent:
            if enableRetry {
                tokenUpdateRetry(
                    requestId: requestId
                )
            }
            return false

        case is ErrorEvent:
            return true

        default:
            userDefault.setCurrentToken(
                provider: currentToken?.provider,
                token: currentToken?.token
            )
            
            return true
        }
    }

    /// Builds and sends the device push token update request.
    ///
    /// - Parameter requestId: Identifier shared by all attempts of the update.
    /// - Returns: `Event` describing success, retry, or error.
    fileprivate func request(
        requestId: String
    ) async -> Event {
        let function = getFunc(#function)

        await backgroundTask.accessToBackground()

        guard let data = await getTokenUpdateRequestData(
            requestId: requestId
        ) else {
            return PushLog.retry(
                function,
                error: PushModuleEvents.updateRequestDataIsNil
            )
        }

        guard let request = await tokenUpdateRequest(data: data) else {
            return PushLog.retry(
                function,
                error: CoreEvents.failedCreateRequest
            )
        }

        return await RequestManager.shared.sendRequest(
            request: request,
            requestData: data
        ).event
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing fileprivate token-update processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension PushTokenProcess {

    /// Test hook for reading current token stored inside token update flow.
    ///
    /// - Returns: Current token used by update flow.
    internal func test_token_update_current_token() async -> TokenData? {
        currentToken
    }

    /// Test hook for overriding current token inside token update flow.
    ///
    /// - Parameter token: Token value to store for tests.
    internal func test_token_update_set_current_token(
        _ token: TokenData?
    ) async {
        currentToken = token
    }

    /// Test hook for internal token update pre-check flow.
    ///
    /// - Parameter enableRetry: If `true`, allows retry scheduling on retryable failure.
    /// - Returns: `true` if update is not needed or flow completes successfully,
    ///   otherwise `false`.
    internal func test_token_update_check(
        enableRetry: Bool
    ) async -> Bool {
        await tokenUpdateCheck(
            enableRetry: enableRetry
        )
    }

    /// Test hook for token update result handling.
    ///
    /// - Parameters:
    ///   - enableRetry: If `true`, allows retry scheduling on retryable failure.
    ///   - requestId: Identifier shared by all attempts of the tested update.
    /// - Returns: `true` for success and non-retry error outcomes, otherwise `false`.
    internal func test_token_update_result(
        enableRetry: Bool,
        requestId: String = UUID().uuidString
    ) async -> Bool {
        await tokenUpdateResult(
            enableRetry: enableRetry,
            requestId: requestId
        )
    }

    /// Test hook for internal token update request flow.
    ///
    /// - Parameter requestId: Identifier used by the tested request.
    /// - Returns: Resulting `Event`.
    internal func test_token_update_request(
        requestId: String = UUID().uuidString
    ) async -> Event {
        await request(
            requestId: requestId
        )
    }
}

/// Builds `TokenUpdateRequestData` for updating the device push token.
///
/// Uses the supplied request identifier during retries. When no identifier
/// is supplied, a new identifier is generated for the initial request.
///
/// - Parameter requestId: Existing request identifier used by a retry attempt.
/// - Returns: Valid token update request data, or `nil` on failure.
func getTokenUpdateRequestData(
    requestId: String? = nil
) async -> RequestModel.TokenUpdateRequestData? {
    let env = PushEnvironment.fresh()

    do {
        try env.checkCoreDataError()

        let savedToken = PushStoredVariables.shared.getSavedToken()
        let currentToken = try await env.currentToken()
        
        return RequestModel.TokenUpdateRequestData(
            path: PushConstants.UrlPath.update,
            requestId: requestId ?? UUID().uuidString,
            oldToken: savedToken?.token,
            newToken: currentToken.token,
            oldProvider: savedToken?.provider,
            newProvider: currentToken.provider,
            sync: try await env.usesRTokenAuth()
        )
    } catch {
        PushLog.error(#function, error: error)
        return nil
    }
}

