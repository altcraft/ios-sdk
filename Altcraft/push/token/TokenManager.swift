//
//  TokenManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Handles push token operations — retrieving, validating, and deleting the device's push token.
/// Supports integration with push notification providers (FCM, HMS, APNs).
final class TokenManager {
    
    static let shared = TokenManager()
    
    var fcmProvider: FCMInterface?
    var hmsProvider: HMSInterface?
    var apnsProvider: APNSInterface?
    
    var tokens = Array<String?>()
    
    let userDefault = StoredVariablesManager.shared

     let validProviders: Set<String> = [
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase,
        Constants.ProviderName.huawei
    ]
    
    /// Validates that all items in the given list are known push providers.
    ///
    /// - Parameter providers: A list of provider identifiers to check.
    /// - Returns: `true` if all values are valid, `false` otherwise.
    func allProvidersValid(_ providers: [String]?) -> Bool {
        guard let providers = providers else { return false }
        return providers.allSatisfy { validProviders.contains($0.lowercased()) }
    }

    /// Deletes the FCM token.
    ///
    /// - Parameter completion: `true` on success, `false` otherwise.
    func deleteFCMToken(completion: @escaping (Bool) -> Void) {
        fcmProvider?.deleteToken(completion: completion)
    }

    /// Deletes the HMS token.
    ///
    /// - Parameter completion: `true` on success, `false` otherwise.
    func deleteHMSToken(completion: @escaping (Bool) -> Void) {
        hmsProvider?.deleteToken(completion: completion)
    }

    /// Retrieves the APNs (Apple Push Notification Service) token if available and non-empty.
    /// Tries up to 3 times with 1-second delays between attempts.
    ///
    /// - Parameter completion: Callback with `TokenData` if successful, `nil` otherwise.
    func getAPNsTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = apnsProvider else {
            completion(nil)
            return
        }
        getNonEmptyToken(
            provider: Constants.ProviderName.apns, fetch: provider.getToken, completion: completion
        )
    }
    
    /// Retrieves the HMS (Huawei Mobile Services) token if available and non-empty.
    /// Tries up to 3 times with 1-second delays between attempts.
    ///
    /// - Parameter completion: Callback with `TokenData` if successful, `nil` otherwise.
    func getFCMTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = fcmProvider else {
            completion(nil)
            return
        }
        getNonEmptyToken(
            provider: Constants.ProviderName.firebase, fetch: provider.getToken, completion: completion
        )
    }
    
    /// Retrieves the HMS (Huawei Mobile Services) token if available and non-empty.
    /// Tries up to 3 times with 1-second delays between attempts.
    ///
    /// - Parameter completion: Callback with `TokenData` if successful, `nil` otherwise.
    func getHMSTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = hmsProvider else {
            completion(nil)
            return
        }
        getNonEmptyToken(
            provider: Constants.ProviderName.huawei, fetch: provider.getToken, completion: completion
        )
    }
    
    /// Returns the device token based on configured provider priority.
    ///
    /// Tries to fetch tokens from APNs, FCM, and HMS. Uses the `providerPriorityList` from config
    /// to determine which token to return first. Falls back to APNs → FCM → HMS if not set.
    ///
    /// Logs the selected token on first use. Returns `nil` if token retrieval fails.
    ///
    /// - Parameter completion: Callback with the selected `TokenData`, or `nil` if no valid token was found.
    func getCurrentToken(completion: @escaping (TokenData?) -> Void) {
        if let manualToken = userDefault.getManualToken() {
            completion(manualToken)
            return
        }

        getConfig { [weak self] (config: Configuration?) in
            guard let self = self else {
                completion(nil)
                return
            }

            let priorityList = config?.providerPriorityList ?? []

            let providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)] = [
                (Constants.ProviderName.apns, self.getAPNsTokenData),
                (Constants.ProviderName.firebase, self.getFCMTokenData),
                (Constants.ProviderName.huawei, self.getHMSTokenData)
            ]

            let orderedProviders = self.sortProvidersByPriority(
                providers: providers,
                priorityList: priorityList
            )

            self.fetchTokensSequentially(providers: orderedProviders) { token in
                if let t = token, (self.tokens.ts_last() ?? nil) != t.token {
                     self.tokenEvent(token: t)
                     self.tokens.ts_append(t.token)
                 }
                completion(token)
            }
        }
    }
    
    /// Sorts the list of token providers according to a given priority list.
    ///
    /// If the `priorityList` is empty, the original provider order is preserved (up to 3 items).
    ///
    /// - Parameters:
    ///   - providers: A list of available providers with their identifiers and fetch functions.
    ///   - priorityList: A list of provider identifiers indicating fetch priority.
    /// - Returns: A sorted list of up to 3 providers in the defined priority order.
    private func sortProvidersByPriority(
        providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)],
        priorityList: [String]
    ) -> [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)] {
        guard !priorityList.isEmpty else {
            return Array(providers.prefix(3))
        }

        var sorted = providers
        sorted.sort { a, b in
            let indexA = priorityList.firstIndex(of: a.type) ?? Int.max
            let indexB = priorityList.firstIndex(of: b.type) ?? Int.max
            return indexA < indexB
        }
        return Array(sorted.prefix(3))
    }
    
    
    /// Sends an event when a push provider is set with its current token.
    ///
    /// - Parameter token: The [`TokenData`] containing the assigned push token. Ignored if `nil` or already sent.
    private func tokenEvent(token: TokenData) {
        event(
            #function,
            event: (pushProviderSet.0, "\(pushProviderSet.1)\(token.provider). token: \(token.token)"),
            value: [
                Constants.MapKeys.provider: token.provider,
                Constants.MapKeys.token: token.token
            ]
        )
    }

    /// Fetches tokens sequentially from a list of providers until a valid token is found.
    ///
    /// - Parameters:
    ///   - providers: A list of providers to query for a token.
    ///   - currentIndex: Index of the current provider being queried (defaults to 0).
    ///   - completion: Called with the first non-nil `TokenData`, or `nil` if all providers failed.

    private func fetchTokensSequentially(
        providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)],
        currentIndex: Int = 0,
        completion: @escaping (TokenData?) -> Void
    ) {
        guard currentIndex < providers.count else {
            completion(nil)
            return
        }
        
        let provider = providers[currentIndex]
        
        provider.fetch { [weak self] (token: TokenData?) in
            if let token = token {
                completion(token)
            } else {
                self?.fetchTokensSequentially(
                    providers: providers, currentIndex: currentIndex + 1, completion: completion
                )
            }
        }
    }
    
    /// Attempts to fetch a non-empty token up to 3 times, retrying every second.
    ///
    /// - Parameters:
    ///   - provider: The name of the provider for metadata purposes.
    ///   - fetch: A function that asynchronously fetches a token string.
    ///   - completion: Called with a valid `TokenData` or `nil` after retries fail.
    private func getNonEmptyToken(
        provider: String,
        fetch: @escaping (@escaping (String?) -> Void) -> Void,
        completion: @escaping (TokenData?) -> Void
    ) {
        var attempts = 3

        func tryFetch() {
            fetch { token in
                if let token = token, !token.isEmpty {
                    completion(TokenData(provider: provider, token: token))
                } else if attempts > 1 {
                    attempts -= 1
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                        tryFetch()
                    }
                } else {
                    completion(nil)
                }
            }
        }
        tryFetch()
    }
}


