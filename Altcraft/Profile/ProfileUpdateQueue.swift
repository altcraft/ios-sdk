//
//  ProfileUpdateQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Serial FIFO async job queue with optional epoch reset.
final class ProfileUpdateCommandQueue: @unchecked Sendable {

    /// A single async job executed by the queue.
    typealias Job = @Sendable () async -> Void

    private let stateQueue: DispatchQueue
    private let usesEpoch: Bool
    private var generation: UInt64 = 0
    private var tail: Task<Void, Never>?

    /// Initializes a new queue.
    ///
    /// - Parameters:
    ///   - label: Internal serial queue label.
    ///   - usesEpoch: Enables epoch-based reset behavior.
    init(label: String, usesEpoch: Bool = false) {
        self.stateQueue = DispatchQueue(label: label)
        self.usesEpoch = usesEpoch
    }

    /// Submits a job to the queue.
    ///
    /// Jobs are executed one at a time, in FIFO order.
    ///
    /// - Parameter job: Async closure to execute.
    func submit(_ job: @escaping Job) {
        stateQueue.async {
            let gen = self.generation
            let prev = self.tail
            let usesEpoch = self.usesEpoch

            let task = Task {
                _ = await prev?.value

                if usesEpoch {
                    let isActual = self.stateQueue.sync {
                        self.generation == gen
                    }
                    guard isActual else { return }
                }

                await job()
            }

            self.tail = task
        }
    }

    /// Resets the queue.
    ///
    /// If `dropCurrent` is `true`, clears pending jobs. When `usesEpoch` is enabled,
    /// also invalidates jobs from the previous generation.
    ///
    /// - Parameter dropCurrent: If `true`, clears queued work and invalidates old jobs.
    func reset(dropCurrent: Bool = true) {
        stateQueue.async {
            guard dropCurrent else { return }
            if self.usesEpoch { self.generation &+= 1 }
            self.tail = nil
        }
    }
}

/// Centralized queues for profile updates.
enum ProfileUpdateQueues {
    /// Serial queue for public profile update commands in call order.
    static let entityQueue = ProfileUpdateCommandQueue(
        label: Constants.Queues.profileUpdateEntityQueue,
        usesEpoch: false
    )

    /// Serial queue for starting profile update processing.
    static let startQueue = ProfileUpdateCommandQueue(
        label: Constants.Queues.profileUpdateStartQueue,
        usesEpoch: true
    )
}
