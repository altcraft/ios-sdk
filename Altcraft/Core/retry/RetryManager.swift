//
//  RetryManager.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// A singleton manager that provides dedicated queues and cancellable work items
/// for retry operations.
///
/// Core owns the generic retry *mechanism*: storing a work item by key (so a
/// newer retry supersedes an older one), cancelling all pending retries, and
/// lazily creating queues for a given label. The **queue labels** themselves are
/// owned by the modules (see `*Constants.RetryQueues`); Core does not know or
/// enumerate them — it creates and caches a queue on first use for whatever
/// label a module supplies.
///
/// The core (authentication) retry uses a dedicated Core-owned queue.
///
/// Allows cancellation of all scheduled retries at once.
@_spi(_Altcraft) public final class RetryManager: @unchecked Sendable {
    public static let shared = RetryManager()
    private init() {}

    /// Serial queue for core (authentication) retry scheduling.
    public let authQueue = DispatchQueue(
        label: Constants.Queues.authQueue,
        qos: .utility
    )

    /// Lazily-created module retry queues, keyed by their label.
    ///
    /// Modules supply the label (from their `*Constants.RetryQueues`) and
    /// receive a stable serial queue; Core never enumerates the module labels.
    private var moduleQueues: [String: DispatchQueue] = [:]

    /// Serial queue providing a stable queue for a given label.
    ///
    /// The first call with a label creates the queue; subsequent calls return
    /// the same instance.
    ///
    /// - Parameter label: The queue label (e.g. a module's retry-queue label).
    /// - Returns: A serial `DispatchQueue` bound to the label.
    public func queue(_ label: String) -> DispatchQueue {
        sync.sync {
            if let existing = moduleQueues[label] {
                return existing
            }
            let created = DispatchQueue(label: label, qos: .utility)
            moduleQueues[label] = created
            return created
        }
    }

    /// Active retry tasks, stored by key.
    private var tasks: [String: DispatchWorkItem] = [:]

    /// Synchronization queue for retry task registry.
    private let sync = DispatchQueue(
        label: Constants.Queues.retryManagerSync
    )

    /// Stores a retry task for later cancellation.
    ///
    /// If a task with the same `key` already exists, it is cancelled
    /// and replaced with the new one.
    ///
    /// - Parameters:
    ///   - key: Unique retry task identifier.
    ///   - work: Work item to schedule or cancel later.
    public func store(
        key: String,
        work: DispatchWorkItem
    ) {
        sync.sync {
            tasks[key]?.cancel()
            tasks[key] = work
        }
    }

    /// Cancels the scheduled retry task for the key, if present.
    ///
    /// - Parameter key: Key the task was stored under.
    public func cancel(key: String) {
        sync.sync { tasks.removeValue(forKey: key)?.cancel() }
    }

    /// Returns `true` when a retry task is currently stored for the given key.
    ///
    /// Test hook: allows verifying whether a retry was scheduled.
    func hasTask(_ key: String) -> Bool {
        sync.sync { tasks[key] != nil }
    }

    /// Cancels all scheduled retry tasks and clears the task registry.
    public func cancelAll() {
        sync.sync {
            for work in tasks.values {
                work.cancel()
            }

            tasks.removeAll()
        }
    }
}
