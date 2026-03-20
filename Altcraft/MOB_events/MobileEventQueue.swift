//
//  MobileEventQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Serial FIFO async job queue with optional epoch reset.
final class MobileEventCommandQueue: @unchecked Sendable {

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

    /// Resets the queue by dropping pending jobs.
    ///
    /// - Parameter dropCurrent: If `true`, invalidates the current epoch
    ///   when `usesEpoch` is enabled.
    func reset(dropCurrent: Bool = true) {
        stateQueue.async {
            guard dropCurrent else { return }
            if self.usesEpoch { self.generation &+= 1 }
            self.tail = nil
        }
    }
}

/// Centralized queues for mobile events.
enum MobileEventQueues {
    /// Serial queue for public mobile event commands in call order.
    static let entityQueue = MobileEventCommandQueue(
        label: Constants.Queues.mobileEventEntityQueue,
        usesEpoch: false
    )

    /// Serial queue for starting mobile event processing.
    static let startQueue = MobileEventCommandQueue(
        label: Constants.Queues.mobileEventStartQueue,
        usesEpoch: true
    )
}
