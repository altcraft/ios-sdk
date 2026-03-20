//
//  TokenManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Handles push token operations — retrieving, validating, saving, and deleting tokens.
///
/// Supports integration with push notification providers:
/// - APNs (`ios-apns`)
/// - Firebase Cloud Messaging (`ios-firebase`)
/// - Huawei Mobile Services (`ios-huawei`)
///
/// Also supports a manually provided token when no push provider is configured.
public actor TokenManager {
    
    /// Shared singleton instance.
    public static let shared = TokenManager()

    /// Tracks previously observed token values to avoid duplicate token events.
    var tokens = Array<String?>()

    /// Registered Firebase token provider.
    public var fcmProvider: FCMInterface?
    
    /// Registered Huawei token provider.
    public var hmsProvider: HMSInterface?
    
    /// Registered APNs token provider.
    public var apnsProvider: APNSInterface?

    private let userDefault = StoredVariablesManager.shared

    /// Supported provider identifiers.
    let validProviders: [String] = [
        Constants.ProviderName.apns,
        Constants.ProviderName.firebase,
        Constants.ProviderName.huawei
    ]

    private init() {}
    
    /// Clears internal token history used for duplicate tracking.
    func clearTokens() { tokens.removeAll()}

    /// Registers or clears the Firebase Cloud Messaging provider.
    ///
    /// - Parameter provider: The FCM provider implementation, or `nil` to unset it.
    public func setFCMProvider(_ provider: FCMInterface?) {
        fcmProvider = provider
    }

    /// Registers or clears the Huawei Mobile Services provider.
    ///
    /// - Parameter provider: The HMS provider implementation, or `nil` to unset it.
    public func setHMSProvider(_ provider: HMSInterface?) {
        hmsProvider = provider
    }

    /// Registers or clears the Apple Push Notification Service provider.
    ///
    /// - Parameter provider: The APNs provider implementation, or `nil` to unset it.
    public func setAPNSProvider(_ provider: APNSInterface?) {
        apnsProvider = provider
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
    
    /// Retrieves the APNs token if available and non-empty.
    ///
    /// Tries up to 3 times with a 1-second delay between attempts.
    ///
    /// - Returns: Token data for APNs, or `nil` if unavailable.
    public func getAPNsTokenData() async -> TokenData? {
        guard let provider = apnsProvider else { return nil }
        return await getNonEmptyToken(
            provider: Constants.ProviderName.apns,
            fetch: provider.getToken
        )
    }

    /// Retrieves the Firebase token if available and non-empty.
    ///
    /// Tries up to 3 times with a 1-second delay between attempts.
    ///
    /// - Returns: Token data for Firebase, or `nil` if unavailable.
    public func getFCMTokenData() async -> TokenData? {
        guard let provider = fcmProvider else { return nil }
        return await getNonEmptyToken(
            provider: Constants.ProviderName.firebase,
            fetch: provider.getToken
        )
    }

    /// Retrieves the Huawei token if available and non-empty.
    ///
    /// Tries up to 3 times with a 1-second delay between attempts.
    ///
    /// - Returns: Token data for Huawei, or `nil` if unavailable.
    public func getHMSTokenData() async -> TokenData? {
        guard let provider = hmsProvider else { return nil }
        return await getNonEmptyToken(
            provider: Constants.ProviderName.huawei,
            fetch: provider.getToken
        )
    }
    
    /// Validates that all items in the given list are known push providers.
    ///
    /// - Parameter providers: A list of provider identifiers to validate.
    /// - Returns: `true` if all providers are supported, otherwise `false`.
    public nonisolated func allProvidersValid(_ providers: [String]?) -> Bool {
        guard let providers else { return false }
        return providers.allSatisfy { validProviders.contains($0.lowercased()) }
    }
    
    /// Returns `true` if any push provider is configured.
    private func providersInstalled() -> Bool {
        (fcmProvider != nil) || (hmsProvider != nil) || (apnsProvider != nil)
    }
    
    /// Indicates whether the push module is currently active.
    ///
    /// The module is considered active when:
    /// - any push provider is configured, or
    /// - a manual token becomes available within 5 seconds.
    ///
    /// - Returns: `true` if the push module is active, otherwise `false`.
    func pushModuleIsActive() async -> Bool {
        if (providersInstalled()) { return true } else {
            return await userDefault.getManualToken() != nil
        }
    }

    /// Returns the current device token according to configured provider priority.
    ///
    /// Behavior:
    /// - If no providers are configured, returns the manual token (waiting up to 5 seconds).
    /// - Otherwise fetches tokens from configured providers in priority order.
    ///
    /// Emits a token event when the resulting token changes.
    ///
    /// - Returns: The selected token data, or `nil` if no token is available.
    func getCurrentToken() async -> TokenData? {
        func trackIfNeeded(_ token: TokenData?) {
            guard let token else { return }
            if tokens.ts_last() != token.token {
                tokenEvent(token: token)
                tokens.ts_append(token.token)
            }
        }
        
        if !providersInstalled() {
            let token = await userDefault.getManualToken()
            trackIfNeeded(token)
            return token
        }

        let priorityList = await getConfig()?.providerPriorityList ?? []
        for fetch in orderedProviderFetchers(priorityList: priorityList) {
            if let token = await fetch() {
                trackIfNeeded(token)
                return token
            }
        }

        return nil
    }

    /// Builds provider fetchers ordered by the configured priority list.
    ///
    /// Any missing providers are appended in the default fallback order:
    /// APNs, Firebase, Huawei.
    ///
    /// - Parameter priorityList: Provider priority from configuration.
    /// - Returns: Ordered async token fetch closures.
    private func orderedProviderFetchers(
        priorityList: [String]
    ) -> [() async -> TokenData?] {
        let providers = validProviders

        let map: [String: () async -> TokenData?] = [
            providers[0]: { [weak self] in await self?.getAPNsTokenData() },
            providers[1]: { [weak self] in await self?.getFCMTokenData() },
            providers[2]: { [weak self] in await self?.getHMSTokenData() }
        ]

        let orderedNames = priorityList.isEmpty ? providers : priorityList

        var seen = Set<String>()

        return orderedNames.compactMap { name in
            guard seen.insert(name).inserted else { return nil }
            return map[name]
        }
    }


    /// Attempts to fetch a non-empty token with retries.
    //
    /// - Parameters:
    ///   - provider: Provider name to store in the resulting `TokenData`.
    ///   - fetch: Callback-based token fetcher.
    /// - Returns: Token data if a non-empty token is obtained, otherwise `nil`.
    private func getNonEmptyToken(
        provider: String,
        fetch: @escaping (@escaping (String?) -> Void) -> Void
    ) async -> TokenData? {
        for attempt in 0..<3 {
            let token = await withCheckedContinuation { с in
                fetch { token in
                    с.resume(returning: token)
                }
            }
            if let token, !token.isEmpty {
                return TokenData(provider: provider, token: token)
            }
            if attempt < 2 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        return nil
    }

    /// Emits an event describing the currently selected push provider and token.
    ///
    /// - Parameter token: The token data to report.
    private func tokenEvent(token: TokenData) {
        event(
            #function,
            event: (
                pushProviderSet.0, "\(pushProviderSet.1)\(token.provider). token: \(token.token)"
            ),
            value: [
                Constants.MapKeys.provider: token.provider, Constants.MapKeys.token: token.token
            ]
        )
    }
}

// MARK: - Unit Test Hooks

extension TokenManager {
    
    /// Test hook: returns currently assigned push token providers.
    ///
    /// Used to safely access actor-isolated provider state in unit tests
    /// without violating Sendable rules in Swift 6.
    internal func test_getProviders() -> (
        fcm: FCMInterface?, hms: HMSInterface?, apns: APNSInterface?
    ) {
        (fcmProvider, hmsProvider, apnsProvider)
    }
    
    /// Test hook: appends a token into internal history.
    ///
    /// Used to prepare duplicate-tracking state in unit tests.
    internal func test_append_token(_ token: String?) {
        tokens.append(token)
    }

    /// Test hook: returns internal token history snapshot.
    ///
    /// Used to verify token history reset in unit tests.
    internal func test_tokens_snapshot() -> [String?] {
        tokens
    }
}
