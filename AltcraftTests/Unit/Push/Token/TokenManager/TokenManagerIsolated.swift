//
//  TokenManager_Isolated.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation
@testable import Altcraft

protocol FCMProviderLike {
    func getToken(_ completion: @escaping (String?) -> Void)
    func deleteToken(completion: @escaping (Bool) -> Void)
}

protocol HMSProviderLike {
    func getToken(_ completion: @escaping (String?) -> Void)
    func deleteToken(completion: @escaping (Bool) -> Void)
}

protocol APNSProviderLike {
    func getToken(_ completion: @escaping (String?) -> Void)
}

final class EventSink {
    struct EventRecord: Equatable {
        let function: String
        let message: String
        let value: [String: String]
    }
    private(set) var events: [EventRecord] = []
    func emit(function: String, message: String, value: [String: String]) {
        events.append(.init(function: function, message: message, value: value))
    }
}

final class TestStoredVariablesManager {
    private let defaults: UserDefaults
    private let manualTokenKey = "MANUAL_TOKEN"
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }
    func setManualToken(_ token: TokenData?) {
        if let token = token, let data = try? JSONEncoder().encode(token) {
            defaults.set(data, forKey: manualTokenKey)
        } else {
            defaults.removeObject(forKey: manualTokenKey)
        }
    }
    func getManualToken() -> TokenData? {
        guard let data = defaults.data(forKey: manualTokenKey) else { return nil }
        return try? JSONDecoder().decode(TokenData.self, from: data)
    }
}

final class TokenManager_Isolated {
    var fcmProvider: FCMProviderLike?
    var hmsProvider: HMSProviderLike?
    var apnsProvider: APNSProviderLike?
    var tokens = Array<String?>()
    let userDefault: TestStoredVariablesManager
    let validProviders: Set<String> = [ Constants.ProviderName.apns, Constants.ProviderName.firebase, Constants.ProviderName.huawei ]
    let eventSink: EventSink
    let getConfig: (@escaping (Configuration?) -> Void) -> Void

    init(userDefaults: TestStoredVariablesManager,
         eventSink: EventSink,
         getConfig: @escaping (@escaping (Configuration?) -> Void) -> Void) {
        self.userDefault = userDefaults
        self.eventSink = eventSink
        self.getConfig = getConfig
    }

    func allProvidersValid(_ providers: [String]?) -> Bool {
        guard let providers = providers else { return false }
        return providers.allSatisfy { validProviders.contains($0.lowercased()) }
    }

    func deleteFCMToken(completion: @escaping (Bool) -> Void) {
        fcmProvider?.deleteToken(completion: completion)
    }

    func deleteHMSToken(completion: @escaping (Bool) -> Void) {
        hmsProvider?.deleteToken(completion: completion)
    }

    func getAPNsTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = apnsProvider else { completion(nil); return }
        getNonEmptyToken(provider: Constants.ProviderName.apns, fetch: provider.getToken, completion: completion)
    }

    func getFCMTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = fcmProvider else { completion(nil); return }
        getNonEmptyToken(provider: Constants.ProviderName.firebase, fetch: provider.getToken, completion: completion)
    }

    func getHMSTokenData(completion: @escaping (TokenData?) -> Void) {
        guard let provider = hmsProvider else { completion(nil); return }
        getNonEmptyToken(provider: Constants.ProviderName.huawei, fetch: provider.getToken, completion: completion)
    }

    func getCurrentToken(completion: @escaping (TokenData?) -> Void) {
        if let manual = userDefault.getManualToken() {
            if (tokens.ts_last() ?? nil) != manual.token {
                tokenEvent(token: manual)
                tokens.ts_append(manual.token)
            }
            completion(manual)
            return
        }
        getConfig { [weak self] cfg in
            guard let self = self else { completion(nil); return }
            let priorityList = cfg?.providerPriorityList ?? []
            let providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)] = [
                (Constants.ProviderName.apns, self.getAPNsTokenData),
                (Constants.ProviderName.firebase, self.getFCMTokenData),
                (Constants.ProviderName.huawei, self.getHMSTokenData)
            ]
            let ordered = self.sortProvidersByPriority(providers: providers, priorityList: priorityList)
            self.fetchTokensSequentially(providers: ordered) { token in
                if let t = token, (self.tokens.ts_last() ?? nil) != t.token {
                    self.tokenEvent(token: t)
                    self.tokens.ts_append(t.token)
                }
                completion(token)
            }
        }
    }

    func sortProvidersByPriority(
        providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)],
        priorityList: [String]
    ) -> [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)] {
        guard !priorityList.isEmpty else { return Array(providers.prefix(3)) }
        var sorted = providers
        sorted.sort { a, b in
            let ia = priorityList.firstIndex(of: a.type) ?? .max
            let ib = priorityList.firstIndex(of: b.type) ?? .max
            return ia < ib
        }
        return Array(sorted.prefix(priorityList.count))
    }

    func tokenEvent(token: TokenData) {
        eventSink.emit(
            function: "tokenEvent()",
            message: "pushProviderSet: \(token.provider). token: \(token.token)",
            value: ["provider": token.provider, "token": token.token]
        )
    }

    func fetchTokensSequentially(
        providers: [(type: String, fetch: (@escaping (TokenData?) -> Void) -> Void)],
        currentIndex: Int = 0,
        completion: @escaping (TokenData?) -> Void
    ) {
        guard currentIndex < providers.count else { completion(nil); return }
        let p = providers[currentIndex]
        p.fetch { [weak self] token in
            if let token = token {
                completion(token)
            } else {
                self?.fetchTokensSequentially(
                    providers: providers,
                    currentIndex: currentIndex + 1,
                    completion: completion
                )
            }
        }
    }

    func getNonEmptyToken(
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
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1) { tryFetch() }
                } else {
                    completion(nil)
                }
            }
        }
        tryFetch()
    }

    func pushModuleIsActive(_ completion: @escaping (Bool) -> Void) {
        let queue = DispatchQueue.global(qos: .utility)
        queue.async { [self] in
            func active() -> Bool {
                (self.userDefault.getManualToken() != nil) || (self.fcmProvider != nil) || (self.hmsProvider != nil) || (self.apnsProvider != nil)
            }
            let maxAttempts = 3
            let delay: TimeInterval = 1.0
            func attempt(_ index: Int) {
                let when: DispatchTime = (index == 1) ? .now() : (.now() + delay)
                queue.asyncAfter(deadline: when) {
                    if active() {
                        completion(true)
                    } else if index < maxAttempts {
                        attempt(index + 1)
                    } else {
                        completion(false)
                    }
                }
            }
            attempt(1)
        }
    }
}

private extension Array where Element == String? {
    func ts_last() -> String?? { self.last }
    mutating func ts_append(_ element: String?) { self.append(element) }
}

