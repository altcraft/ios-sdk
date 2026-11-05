//
//  SerialCommandQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Serial FIFO async job queue with optional epoch reset.
@_spi(_Altcraft) public final class SerialCommandQueue: @unchecked Sendable {
    /// A single async job executed by the queue.
    public typealias Job = @Sendable () async -> Void

    private let stateQueue: DispatchQueue
    private let usesEpoch: Bool
    private var generation: UInt64 = 0
    private var suspended = false
    private var tail: Task<Void, Never>?

    /// Validity of the queue operation across suspension points.
    @TaskLocal public static var isCurrent: @Sendable () -> Bool = { true }

    /// Starts a synchronous operation atomically with respect to queue reset.
    @TaskLocal public static var performIfCurrent: @Sendable (@Sendable () -> Void) -> Bool = { operation in
        operation()
        return true
    }

    /// Invalidates delivery and rejects new starts while persistent data is cleared.
    public func suspend() {
        stateQueue.sync {
            suspended = true
            generation &+= 1
            tail?.cancel()
            tail = nil
        }
    }

    /// Resumes command execution after `suspend()`.
    ///
    /// Has no effect when the queue is not suspended.
    public func resume() {
        stateQueue.sync { suspended = false }
    }

    /// Drops waiting commands and waits for the active producer to finish.
    public func resetAndWait() async {
        let previous = stateQueue.sync {
            generation &+= 1
            let previous = tail
            tail = nil
            return previous
        }
        await previous?.value
    }

    /// Initializes a new queue.
    ///
    /// - Parameters:
    ///   - label: Internal serial queue label.
    ///   - usesEpoch: Enables epoch-based reset behavior.
    public init(label: String, usesEpoch: Bool = false) {
        self.stateQueue = DispatchQueue(label: label)
        self.usesEpoch = usesEpoch
    }

    /// Submits a job to the queue.
    ///
    /// Jobs are executed one at a time, in FIFO order.
    ///
    /// The chaining block runs synchronously on the state queue so that a
    /// concurrent ``reset()`` cannot slip between job submission and tail
    /// linking; otherwise a job submitted before a reset could start
    /// unchained and break FIFO ordering.
    ///
    /// - Parameter job: Async closure to execute.
    public func submit(_ job: @escaping Job) {
        let parentCheck = Self.isCurrent
        stateQueue.sync {
            guard !self.suspended else { return }
            let gen = self.generation
            let prev = self.tail
            let usesEpoch = self.usesEpoch

            let task = Task {
                _ = await prev?.value

                if usesEpoch {
                    let isActual = self.stateQueue.sync {
                        self.generation == gen
                    }
                    guard isActual else {
                        return
                    }
                }
                // A tail cancelled by reset()/suspend() must not run its job;
                // without this check the "dropped" work would still execute
                // and interleave with post-reset submissions.
                guard !Task.isCancelled else { return }
                guard parentCheck() else { return }
                await Self.$isCurrent.withValue({
                    parentCheck() && (!usesEpoch || self.stateQueue.sync { self.generation == gen })
                }) {
                    await Self.$performIfCurrent.withValue({ operation in
                        guard parentCheck() else { return false }
                        return self.stateQueue.sync {
                            guard !usesEpoch || self.generation == gen else { return false }
                            operation()
                            return true
                        }
                    }) {
                        await job()
                    }
                }
            }
            self.tail = task
        }
    }

    /// Resets the queue by dropping pending jobs.
    ///
    /// - Parameter dropCurrent: If `true`, invalidates the current epoch
    ///   when `usesEpoch` is enabled **and** cancels the in-flight tail task
    ///   so that a job blocked on `await prev?.value` is also dropped.
    public func reset(dropCurrent: Bool = true) {
        stateQueue.sync {
            guard dropCurrent else { return }
            if self.usesEpoch { self.generation &+= 1 }
            self.tail?.cancel()
            self.tail = nil
        }
    }
}
