//
//  RetryManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton manager that provides dedicated queues and cancellable work items
/// for retry operations (subscribe, token update, and push event).
/// Allows cancellation of all scheduled retries at once.
final class RetryManager {
    static let shared = RetryManager()
    private init() {}

    /// Serial queue for subscription retries.
    let subscribeQueue = DispatchQueue(label: Constants.Queues.retrySubscribeQueue, qos: .utility)

    /// Serial queue for token update retries.
    let tokenUpdateQueue = DispatchQueue(label: Constants.Queues.retryTokenUpdateQueue, qos: .utility)

    /// Serial queue for push event retries.
    let pushEventQueue = DispatchQueue(label: Constants.Queues.retryPushEventQueue, qos: .utility)

    /// Active retry tasks, stored by key.
    private var tasks: [String: DispatchWorkItem] = [:]
    private let sync = DispatchQueue(label: Constants.Queues.retryManagerSync)

    /// Stores a retry task for later cancellation.
    func store(key: String, work: DispatchWorkItem) {
        sync.sync {
            tasks[key]?.cancel()
            tasks[key] = work
        }
    }

    /// Cancels all scheduled retry tasks across all queues.
    func cancelAll() {
        sync.sync {
            for (_, work) in tasks {
                work.cancel()
            }
            tasks.removeAll()
        }
    }
}
