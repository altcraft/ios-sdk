//
//  TokenUpdate.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton class responsible for handling  device token updates for Altcraft profiles .
public class TokenUpdate: NSObject {
    public static let shared = TokenUpdate()
    private let pushSubscribe = PushSubscribe.shared
    private let tokenManager = TokenManager.shared
    let backgroundTask = AccessToBackground.shared
    let userDefault = StoredVariablesManager.shared
    let funcName = Constants.FunctionsCode.SU
    let retry = {requestRetry(request: Constants.FunctionsCode.SU)}
    var currentToken: TokenData? = nil
    private let tokenUpdateQueue = DispatchQueue(label: Constants.Queues.tokenUpdateQueue)
  
    /// Initiates the device push token update process for Altcraft profiles.
    ///
    /// Compares the saved push token with the current one. If the tokens differ,
    /// starts the update process and saves the retry counter. Otherwise,
    /// triggers a subscription check.
    ///
    /// - Parameters:
    ///   - completion: Optional closure called after the operation completes.
    func tokenUpdate(completion: (() -> Void)? = nil) {
        tokenUpdateQueue.async {
            let savedToken = self.userDefault.getSavedToken()

            self.tokenManager.getCurrentToken { currentToken in
                guard let currentToken = currentToken else {
                    errorEvent(#function, error: currentTokenIsNil)
                    return self.tokenUpdateQueue.async {
                        completion?()
                    }
                }

                self.currentToken = currentToken

                if savedToken?.token != currentToken.token {
                    self.backgroundTask.accessToBackground()
                    self.userDefault.setUpdateRetryCount(value: 1)
                    self.startUpdate {
                        self.tokenUpdateQueue.async {
                            completion?()
                        }
                    }
                } else {
                    self.tokenUpdateQueue.async {
                        completion?()
                    }
                }
            }
        }
    }
    
    /// Starts the token update process.
    ///
    /// - Parameter completion: Optional closure called after the update finishes.
    func startUpdate (completion: (() -> Void)? = nil) {
        sendUpdateRequest { event in
            if event is RetryEvent {
                self.retry()
                completion?()
                return
            }
            
            if !(event is ErrorEvent) {
                self.userDefault.setCurrentToken(
                    provider: self.currentToken?.provider,
                    token: self.currentToken?.token
                )
            }
            completion?()
        }
    }
    
    /// Sends the device push token **update** request.
    ///
    /// Builds the request using `getUpdateRequestData()` and `updateRequest(data:)`.
    /// If data is missing or the request cannot be created, completes with a `RetryEvent`.
    /// Otherwise, forwards the resulting `Event` from `RequestManager`.
    ///
    /// - Parameter completion: Closure invoked with the resulting `Event`
    ///   (success, non-retryable error, or `RetryEvent`).
    func sendUpdateRequest(completion: @escaping (Event) -> Void) {
        getUpdateRequestData{ data in
            guard let data = data else {
                completion(retryEvent(#function, error: updateRequestDataIsNil))
                return
            }
            guard let request = updateRequest(data: data) else {
                completion(retryEvent(#function, error: failedCreateRequest))
                return
            }
            RequestManager.shared.sendRequest(
                request: request, requestName: Constants.RequestName.update, completion: completion
            )
        }
    }
}

