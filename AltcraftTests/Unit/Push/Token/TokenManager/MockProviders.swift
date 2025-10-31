//
//  TokenProviders_Mocks.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import Foundation

/// Mock FCM provider for testing token retrieval and deletion
final class MockFCMProvider: FCMProviderLike {
    private var tokensQueue: [String?]
    private(set) var deleteCalled = false
    
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    
    /// Returns next token from queue or nil if empty
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
    
    /// Marks token deletion as called and returns success
    func deleteToken(completion: @escaping (Bool) -> Void) {
        deleteCalled = true
        completion(true)
    }
}

/// Mock HMS provider for testing Huawei token operations
final class MockHMSProvider: HMSProviderLike {
    private var tokensQueue: [String?]
    private(set) var deleteCalled = false
    
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    
    /// Returns next token from queue or nil if empty
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
    
    /// Marks token deletion as called and returns success
    func deleteToken(completion: @escaping (Bool) -> Void) {
        deleteCalled = true
        completion(true)
    }
}

/// Mock APNS provider for testing Apple Push Notification token retrieval
final class MockAPNSProvider: APNSProviderLike {
    private var tokensQueue: [String?]
    
    init(tokensQueue: [String?]) {
        self.tokensQueue = tokensQueue
    }
    
    /// Returns next token from queue or nil if empty
    func getToken(_ completion: @escaping (String?) -> Void) {
        let next = tokensQueue.isEmpty ? nil : tokensQueue.removeFirst()
        completion(next)
    }
}
