//
//  UpdateCoordinator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// Coalesces concurrent calls into a single in-flight operation.
/// While running, collects completions; on finish, delivers the same result to all.
/// `operation` must call `done` exactly once.
final class UpdateCoordinator<Result> {

    typealias Completion = (Result) -> Void
    typealias Operation = (@escaping Completion) -> Void

    private let queue: DispatchQueue
    private var isRunning: Bool = false
    private var pending: [Completion] = []
    private let queueKey = DispatchSpecificKey<Void>()

    init(label: String) {
        self.queue = DispatchQueue(label: label)
        self.queue.setSpecific(key: queueKey, value: ())
    }

    /// Coalesces concurrent calls into a single in-flight operation.
    /// If an operation is already running, only enqueues `completion`.
    ///
    /// - Parameters:
    ///   - operation: Must call `done` exactly once.
    ///   - completion: Optional callback receiving the shared result.
    func run(
        operation: @escaping Operation,
        completion: Completion? = nil
    ) {
        onQueue { [weak self] in
            guard let self else { return }

            if let completion {
                self.pending.append(completion)
            }

            if self.isRunning { return }
            self.isRunning = true

            operation { [weak self] result in
                self?.finish(result)
            }
        }
    }

    /// Executes `block` on the internal serial queue.
    /// If already on that queue, executes immediately.
    ///
    /// - Parameter block: Work to execute.
    private func onQueue(_ block: @escaping () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            block()
        } else {
            queue.async(execute: block)
        }
    }

    /// Completes the current operation and delivers `result`
    /// to all pending completions.
    ///
    /// - Parameter result: Result to deliver.
    private func finish(_ result: Result) {
        onQueue { [weak self] in
            guard let self else { return }
            self.isRunning = false

            let completions = self.pending
            self.pending.removeAll(keepingCapacity: true)

            completions.forEach { $0(result) }
        }
    }
}
