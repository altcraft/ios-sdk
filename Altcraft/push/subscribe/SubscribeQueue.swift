//
//  SubscribeQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import Foundation

/// Serial FIFO job queue with optional "epoch" reset mechanism.
/// Jobs are executed one at a time. Each job receives a `done()`
/// callback and must call it once to release the queue.
///
/// If `usesEpoch` is enabled, calling `reset()` invalidates the
/// current job chain so that jobs from an old generation cannot
/// continue the queue.
final class SubscribeCommandQueue {
    /// Typealias for a job. Each job must call the provided `done()` closure when finished.
    public typealias Job = (@escaping () -> Void) -> Void
    
    private let serial: DispatchQueue
    private var queue: [(generation: Int, job: Job)] = []
    private var running = false
    
    private let usesEpoch: Bool
    private var generation = 0
    
    /// Initializes a new queue.
    /// - Parameters:
    ///   - label: Label for the underlying serial `DispatchQueue`.
    ///   - usesEpoch: If `true`, enables epoch-based reset (old jobs won't continue after reset).
    public init(label: String, usesEpoch: Bool = false) {
        self.serial = DispatchQueue(label: label)
        self.usesEpoch = usesEpoch
    }
    
    /// Submits a job to the queue.
    /// - Parameter job: Closure that accepts a `done()` callback. Must call `done()` exactly once.
    public func submit(_ job: @escaping Job) {
        serial.async {
            let gen = self.generation
            self.queue.append((generation: gen, job: job))
            guard !self.running else { return }
            self.running = true
            self.runNext()
        }
    }
    
    /// Resets the queue by removing all pending jobs.
    /// - Parameter dropCurrent:
    ///   If `true`, also invalidates the currently running job chain
    ///   (in epoch mode). Its `done()` will not continue execution.
    public func reset(dropCurrent: Bool = true) {
        serial.async {
            self.queue.removeAll()
            if self.usesEpoch {
                if dropCurrent {
                    self.generation &+= 1
                    self.running = false
                }
            } else {
                if dropCurrent {
                    self.running = false
                }
            }
        }
    }
    
    /// Executes the next job in the queue if available.
    private func runNext() {
        guard !queue.isEmpty else {
            running = false
            return
        }
        let item = queue.removeFirst()
        let jobGen = item.generation
        item.job { [weak self] in
            guard let self = self else { return }
            self.serial.async {
                if self.usesEpoch {
                    if jobGen == self.generation {
                        self.runNext()
                    }
                } else {
                    self.runNext()
                }
            }
        }
    }
}

/// Centralized queues used by the push subscription subsystem.
enum SubscribeQueues {
    /// Serial queue for sequential creation of subscription entities.
    static let entityQueue = SubscribeCommandQueue(label: Constants.Queues.subscribeEntityQueue, usesEpoch: false)
    
    /// Serial queue for starting subscription processing.
    /// Supports reset with epoch to prevent continuation after retry.
    static let startQueue  = SubscribeCommandQueue(label:  Constants.Queues.subscribeStartQueue, usesEpoch: true)
    
    /// Plain serial queue for synchronizing internal state/flags.
    static let syncQueue   = DispatchQueue(label: Constants.Queues.subscribeSyncQueue)
}
