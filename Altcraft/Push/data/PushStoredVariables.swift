//
//  PushStoredVariables.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// A singleton actor responsible for managing push-related stored variables.
///
/// Persists device/manual push tokens in `UserDefaults` with SDK-prefixed keys.
/// The push module owns these keys; core does not read or write them.
actor PushStoredVariables {

    /// The shared instance of `PushStoredVariables`.
    static let shared = PushStoredVariables()

    private static let tokenKey = "\(PushConstants.UDPrefix)_CURRENT_TOKEN"
    private static let manualTokenKey = "\(PushConstants.UDPrefix)_MANUAL_TOKEN"

    private init() {}

    /// Stores the current push token in UserDefaults if both `provider` and
    /// `token` are non-empty.
    ///
    /// - Parameters:
    ///   - provider: Non-optional provider string.
    ///   - token: Optional token string. If `nil`, nothing is saved.
    nonisolated func setCurrentToken(provider: String?, token: String?) {
        guard
            let provider,
            let token,
            !provider.isEmpty,
            !token.isEmpty
        else { return }

        let stored = TokenData(provider: provider, token: token)
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.tokenKey)
        }
    }

    /// Retrieves the saved push token and provider from UserDefaults.
    ///
    /// - Returns: A `TokenData` object if valid data exists, otherwise `nil`.
    nonisolated func getSavedToken() -> TokenData? {
        guard let data = UserDefaults.standard.data(forKey: Self.tokenKey) else {
            return nil
        }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }

    /// Removes the saved (last known valid) push token from UserDefaults.
    nonisolated func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: Self.tokenKey)
    }

    private var manualTokenWaiters: [
        UUID: CheckedContinuation<TokenData?, Never>
    ] = [:]

    /// Removes the manual stored push token from UserDefaults.
    func clearManualToken() {
        UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

        if !manualTokenWaiters.isEmpty {
            let waiters = manualTokenWaiters.values
            manualTokenWaiters.removeAll()
            for waiter in waiters {
                waiter.resume(returning: nil)
            }
        }
    }

    /// Stores the manual push token or clears it.
    ///
    /// - Parameters:
    ///   - provider: Provider id (`ios-apns` / `ios-firebase` / `ios-huawei`).
    ///   - token: Token value.
    func setPushToken(provider: String, token: String?) {
        guard let token, !provider.isEmpty, !token.isEmpty else {
            UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
            return
        }

        let stored = TokenData(provider: provider, token: token)

        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: stored)
                }
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.manualTokenKey)

            if !manualTokenWaiters.isEmpty {
                let waiters = manualTokenWaiters.values
                manualTokenWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(returning: nil)
                }
            }
        }
    }

    /// Returns the manual push token.
    ///
    /// If a token is already stored, returns immediately. Otherwise waits until
    /// a token is set via `setPushToken(provider:token:)`, but no longer than
    /// 5 seconds.
    ///
    /// - Returns: Stored `TokenData` once available, or `nil` on timeout.
    func getManualToken() async -> TokenData? {
        if let data = UserDefaults.standard.data(forKey: Self.manualTokenKey),
           let existing = try? JSONDecoder().decode(TokenData.self, from: data) {
            return existing
        }

        let id = UUID()

        return await withCheckedContinuation { continuation in
            manualTokenWaiters[id] = continuation

            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }
                await self.resumeManualTokenWaiterIfNeeded(id: id)
            }
        }
    }

    /// Resumes the manual token waiter registered under the identifier
    /// with `nil`.
    ///
    /// - Parameter id: Waiter identifier.
    private func resumeManualTokenWaiterIfNeeded(id: UUID) {
        guard let waiter = manualTokenWaiters.removeValue(forKey: id) else { return }
        waiter.resume(returning: nil)
    }

    /// Clears all push-related values stored in UserDefaults.
    ///
    /// Removes push token keys from standard and App Group UserDefaults and
    /// resumes pending manual token waiters with `nil`.
    func clearAll() {
        let keys = [
            Self.tokenKey,
            Self.manualTokenKey
        ]

        keys.forEach {
            UserDefaults.standard.removeObject(forKey: $0)
        }

        if let groupName = StoredVariablesManager.shared.getGroupName(),
           let groupDefaults = UserDefaults(suiteName: groupName) {
            keys.forEach {
                groupDefaults.removeObject(forKey: $0)
            }
        }

        if !manualTokenWaiters.isEmpty {
            let waiters = manualTokenWaiters.values
            manualTokenWaiters.removeAll()

            for waiter in waiters {
                waiter.resume(returning: nil)
            }
        }
    }
}
