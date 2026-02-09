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
final class TokenUpdate: NSObject {

    public static let shared = TokenUpdate()
    private let pushSubscribe = PushSubscribe.shared
    private let tokenManager = TokenManager.shared
    let backgroundTask = AccessToBackground.shared
    let userDefault = StoredVariablesManager.shared
    private func retry() { localTokenUpdateRetry() }
    var currentToken: TokenData? = nil

    private let coordinator = UpdateCoordinator<Bool>(
        label: Constants.Queues.tokenUpdateQueue
    )

    private override init() { super.init() }

    /// Initiates the device push token update flow.
    ///
    /// Completion returns:
    /// - false: if tokenUpdate failed OR if update produced RetryEvent
    /// - true:  for any other outcome (including "no update needed")
    func tokenUpdate(completion: ((Bool) -> Void)? = nil) {
        coordinator.run(operation: { [weak self] done in
            guard let self else { done(false); return }
            self.performTokenUpdate(done: done)
        }, completion: completion)
    }
    
    /// Performs the device push token update flow.
    ///
    /// - Parameter done: Completion handler called when the flow finishes.
    ///   Passes:
    ///   - `true` if update is not needed or the update flow finishes successfully
    ///   - `false` if the flow fails.
    private func performTokenUpdate(done: @escaping (Bool) -> Void) {
        guard let savedToken = self.userDefault.getSavedToken() else {
            return done(true)
        }
        
        self.tokenManager.getCurrentToken { [weak self]
            currentToken in
            
            guard let self else { done(false); return }

            guard let currentToken = currentToken else {
                errorEvent(#function, error: pushTokenIsNil)
                done(false)
                return
            }
            
            self.currentToken = currentToken

            if savedToken.token == currentToken.token {
                done(true)
                return
            }
            
            self.backgroundTask.accessToBackground()
            updateRetryCount = 0
            
            self.startUpdate { [weak self] success in
                guard self != nil else { done(false); return }
                done(success)
            }
        }
    }

    /// Starts the token update process.
    ///
    /// Completion returns:
    /// - false: if event is RetryEvent
    /// - true:  for any other event type (including ErrorEvent)
    func startUpdate(completion: ((Bool) -> Void)? = nil) {
        sendUpdateRequest { [weak self] event in
            guard let self else { return }
            
            if event is RetryEvent {
                self.retry()
                completion?(false)
                return
            }
            
            if !(event is ErrorEvent) {
                self.userDefault.setCurrentToken(
                    provider: self.currentToken?.provider,
                    token: self.currentToken?.token
                )
            }
            
            completion?(true)
        }
    }

    /// Sends the device push token update request.
    func sendUpdateRequest(completion: @escaping (Event) -> Void) {
        getUpdateRequestData { data in
            guard let data = data else {
                completion(retryEvent(#function, error: updateRequestDataIsNil))
                return
            }
            guard let request = updateRequest(data: data) else {
                completion(retryEvent(#function, error: failedCreateRequest))
                return
            }
            RequestManager.shared.sendRequest(
                request: request, requestName: Constants.RequestName.update,completion: completion
            )
        }
    }
}
