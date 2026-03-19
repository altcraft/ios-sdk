//
//  TokenUpdate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton class responsible for handling device token updates for Altcraft profiles .
@available(iOSApplicationExtension, unavailable)
final actor TokenUpdate {

    static let shared = TokenUpdate()
    
    private let tokenManager = TokenManager.shared
    private let backgroundTask = AccessToBackground.shared
    private let userDefault = StoredVariablesManager.shared

    var currentToken: TokenData?
    
    private let coordinator = UpdateCoordinator<Bool>()
    private let retryReset: () = RetryCounters.shared.reset(
        RetryKey.tokenUpdate
    )
    
    /// Builds a formatted function tag for logs.
    ///
    /// - Parameter name: The source function name.
    private func getFunc(_ name: String) -> String {
        "\(name) :: TokenUpdate"
    }

    private init() {}

    /// Initiates the device push token update flow.
    ///
    /// Returns:
    /// - false: if tokenUpdate failed OR if update produced RetryEvent
    /// - true:  for any other outcome (including "no update needed")
    func tokenUpdate(enableRetry: Bool = true) async -> Bool {
        await coordinator.run(operation: {
            return await self.tokenUpdateCheck(enableRetry: enableRetry)
        })
    }

    /// Performs the device push token update flow.
    ///
    /// - Returns:
    ///   - `true` if update is not needed or the update flow finishes successfully
    ///   - `false` if the flow fails.
    /// Performs the device push token update flow.
    fileprivate func tokenUpdateCheck(enableRetry: Bool) async -> Bool {
        let env = Environment.create()

        do {
            let saved =  env.savedToken()
            if saved == nil { return true }
            let current = try await env.token()
            if saved?.token == current.token {
                return true
            }
            
            currentToken = current
            retryReset
            
            return await tokenUpdateResult(enableRetry: enableRetry)
        } catch {
            errorEvent(#function, error: error)
            return false
        }
    }
    
    /// Handles the update outcome based on request result.
    ///
    /// Returns:
    /// - false: if event is RetryEvent
    /// - true:  for any other event type (including ErrorEvent)
    func tokenUpdateResult(enableRetry: Bool) async -> Bool {
        switch await request() {
        case is RetryEvent:
            if enableRetry {
                tokenUpdateRetry()
            }
            return false
        case is ErrorEvent:
            return true
        default:
            userDefault.setCurrentToken(
                provider: currentToken?.provider, token: currentToken?.token
            )
            return true
        }
    }
    
    /// Builds and sends the device push token update request.
    ///
    /// - Returns: `Event` describing success / retry / error.
    fileprivate func request() async -> Event {
        let function = getFunc(#function)
        await backgroundTask.accessToBackground()
        
        guard let data = await getTokenUpdateRequestData() else {
            return retryEvent(
                function, error: updateRequestDataIsNil
            )
        }
        
        guard let request = tokenUpdateRequest(data: data) else {
            return retryEvent(
                function, error: failedCreateRequest
            )
        }
        
        return await RequestManager.shared.sendRequest(
            request: request, requestName: Constants.RequestName.tokenUpdate
        )
    }
}


// MARK: - Unit Test Hooks

/// Extension exposing fileprivate token-update processing hooks for unit tests.
@available(iOSApplicationExtension, unavailable)
extension TokenUpdate {
    
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
    /// - Returns: `true` if update is not needed or flow completes successfully, otherwise `false`.
    internal func test_token_update_check(
        enableRetry: Bool
    ) async -> Bool {
        await tokenUpdateCheck(enableRetry: enableRetry)
    }

    /// Test hook for token update result handling.
    ///
    /// - Parameter enableRetry: If `true`, allows retry scheduling on retryable failure.
    /// - Returns: `true` for success and non-retry error outcomes, otherwise `false`.
    internal func test_token_update_result(
        enableRetry: Bool
    ) async -> Bool {
        await tokenUpdateResult(enableRetry: enableRetry)
    }

    /// Test hook for internal token update request flow.
    ///
    /// - Returns: Resulting `Event`.
    internal func test_token_update_request() async -> Event {
        await request()
    }
}
