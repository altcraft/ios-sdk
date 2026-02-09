//
//  RetryManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A singleton manager that provides dedicated queues and cancellable work items
/// for retry operations (subscribe, token update, push event, and mobile event).
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
    
    /// Serial queue for mobile event retries.
    let mobileEventQueue = DispatchQueue(label: Constants.Queues.retryMobileEventQueue, qos: .utility)

    /// Active retry tasks, stored by key.
    var tasks: [String: DispatchWorkItem] = [:]
    private let sync = DispatchQueue(label: Constants.Queues.retryManagerSync)

    /// Stores a retry task for later cancellation.
    ///
    /// If a task with the same `key` already exists, it will be cancelled
    /// and replaced with the new one.
    ///
    /// - Parameters:
    ///   - key: Unique identifier of the retry task.
    ///   - work: The `DispatchWorkItem` to schedule/cancel later.
    func store(key: String, work: DispatchWorkItem) {
        sync.sync {
            tasks[key]?.cancel()
            tasks[key] = work
        }
    }

    /// Cancels all scheduled retry tasks across all queues and clears the registry.
    func cancelAll() {
        sync.sync {
            for (_, work) in tasks {
                work.cancel()
            }
            tasks.removeAll()
        }
    }
}
