//
//  TokenProviders_Mocks.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

final class MockFCMProvider: FCMProviderLike {
    private var tokensQueue: [String?]
    private(set) var deleteCalled = false
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
    func deleteToken(completion: @escaping (Bool) -> Void) {
        deleteCalled = true
        completion(true)
    }
}

final class MockHMSProvider: HMSProviderLike {
    private var tokensQueue: [String?]
    private(set) var deleteCalled = false
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
    func deleteToken(completion: @escaping (Bool) -> Void) {
        deleteCalled = true
        completion(true)
    }
}

final class MockAPNSProvider: APNSProviderLike {
    private var tokensQueue: [String?]
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
}

