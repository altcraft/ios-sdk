//
//  MobileEventQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation
import CoreData

/// Serial FIFO job queue with optional epoch reset (like `SubscribeCommandQueue`).
final class MobileEventCommandQueue {
    typealias Job = (@escaping () -> Void) -> Void

    private let serial: DispatchQueue
    private var queue: [(gen: Int, job: Job)] = []
    private var running = false

    private let usesEpoch: Bool
    private var generation = 0

    /// Initializes the command queue.
    /// - Parameters:
    ///   - label: Queue label for debugging.
    ///   - usesEpoch: Enables epoch-based reset logic.
    init(label: String, usesEpoch: Bool = false) {
        self.serial = DispatchQueue(label: label)
        self.usesEpoch = usesEpoch
    }

    /// Adds a job to the queue.
    /// - Parameter job: A closure that performs async work and calls its completion when done.
    func submit(_ job: @escaping Job) {
        serial.async {
            let g = self.generation
            self.queue.append((g, job))
            guard !self.running else { return }
            self.running = true
            self.runNext()
        }
    }

    /// Clears queued jobs and optionally resets the current run state.
    /// - Parameter dropCurrent: If `true`, cancels the current job as well.
    func reset(dropCurrent: Bool = true) {
        serial.async {
            self.queue.removeAll()
            if self.usesEpoch {
                if dropCurrent {
                    self.generation &+= 1
                    self.running = false
                }
            } else if dropCurrent {
                self.running = false
            }
        }
    }

    /// Runs the next queued job if available.
    private func runNext() {
        guard !queue.isEmpty else { running = false; return }
        let item = queue.removeFirst()
        let jobGen = item.gen
        item.job { [weak self] in
            guard let self else { return }
            self.serial.async {
                if self.usesEpoch {
                    if jobGen == self.generation { self.runNext() }
                } else {
                    self.runNext()
                }
            }
        }
    }
}
/// Centralized queues for mobile events.
enum MobileEventQueues {
    static let entityQueue = MobileEventCommandQueue(label: Constants.Queues.mobileEventEntityQueue, usesEpoch: false)
    static let startQueue  = MobileEventCommandQueue(label: Constants.Queues.mobileEventStartQueue, usesEpoch: true)
    static let syncQueue   = DispatchQueue(label: Constants.Queues.mobileEventSyncQueue)
}
