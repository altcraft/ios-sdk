//
//  InitBarrier.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

/// A single-process initialization gate.
///
/// `InitGate` represents a single “initialization round”. Callers can register closures via
/// `addWaiter(_:)` that will be executed once the gate is completed.
///
/// The gate is completed exactly once per round using `complete()`. After completion,
/// all current and future waiters are executed immediately.
internal final class InitGate {
    private let q = DispatchQueue(
        label: Constants.Queues.initGateQueue
    )
    private var isCompleted: Bool = false
    private var waiters: [() -> Void] = []

    /// Registers a closure to be executed after the gate completes.
    ///
    /// If the gate is already completed, the closure is executed immediately.
    ///
    /// - Parameter waiter: A closure to run once initialization for this gate is completed.
    func addWaiter(_ waiter: @escaping () -> Void) {
        q.async {
            if self.isCompleted {
                waiter()
                return
            }
            self.waiters.append(waiter)
        }
    }

    /// Completes the gate and releases all registered waiters.
    ///
    /// Subsequent calls have no effect.
    func complete() {
        q.async {
            guard !self.isCompleted else { return }
            self.isCompleted = true

            let toCall = self.waiters
            self.waiters.removeAll(keepingCapacity: true)
            toCall.forEach {
                $0()
            }
        }
    }

    /// Reads the completion state in a thread-safe manner.
    ///
    /// - Parameter cb: A closure receiving `true` if the gate is completed, otherwise `false`.
    func completedSnapshot(_ cb: @escaping (_ completed: Bool) -> Void) {
        q.async { cb(self.isCompleted) }
    }
}

/// A single-process initialization barrier.
///
/// `InitBarrier` owns the current `InitGate` and allows the SDK to create a new initialization round
/// when the previous one has already completed. Consumers typically:
/// - capture a snapshot gate using `current()`
/// - wait for it using `withInitReady(function:gate:block:)`
///
/// The initialization path should call `reserve()` at the start of init and `complete(_:)` when init
/// is finished, releasing all waiters.
internal final class InitBarrier {

    /// Shared singleton instance.
    static let shared = InitBarrier()

    private let q = DispatchQueue(
        label: Constants.Queues.initBarrierStateQueue
    )

    private var gate: InitGate = InitGate()

    private init() {}

    /// Returns the current initialization gate.
    ///
    /// Use this method to capture a stable snapshot of the current initialization round.
    ///
    /// - Returns: The current `InitGate`.
    func current() -> InitGate {
        q.sync { gate }
    }

    /// Reserves an initialization gate for a new init round.
    ///
    /// If the current gate is already completed, a new gate is created and returned.
    /// Otherwise, the current (in-progress) gate is returned.
    ///
    /// - Returns: A gate representing the active initialization round.
    func reserve() -> InitGate {
        q.sync {
            let cur = gate
            var completed = false
            let sem = DispatchSemaphore(value: 0)
            cur.completedSnapshot {
                completed = $0
                sem.signal()
            }
            sem.wait()
            if !completed { return cur }
            let next = InitGate()
            gate = next
            return next
        }
    }

    /// Completes the provided initialization gate.
    ///
    /// - Parameter gate: The `InitGate` instance previously obtained from `reserve()`.
    func complete(_ gate: InitGate) {
        gate.complete()
    }
}

/// Awaits completion of the provided initialization gate.
///
/// If the gate is already completed, `completion` is called immediately.
/// Otherwise, the caller is registered as a waiter and will be invoked once the gate completes.
/// If `timeoutMs` is not `nil` and the gate is still not completed after the timeout,
/// `sdkInitWaitingExpired` is emitted and `completion` is invoked anyway.
///
/// - Parameters:
///   - function: Logical source tag used for event logging.
///   - gate: The `InitGate` to wait for. Defaults to the current gate snapshot.
///   - timeoutMs: Timeout in milliseconds. Pass `nil` to wait indefinitely.
///   - completion: Closure called once the gate completes or the timeout expires.
internal func awaitInit(
    function: String,
    gate: InitGate = InitBarrier.shared.current(),
    timeoutMs: Int? = 7_000,
    completion: @escaping () -> Void
) {
    gate.completedSnapshot { completed in
        if completed {
            completion()
            return
        }

        event(function, event: initAwait)

        let stateQ = DispatchQueue(
            label: Constants.Queues.initBarrierAwaitQueue
        )

        var didFinish = false

        func finish() {
            stateQ.async {
                if didFinish { return }
                didFinish = true
                completion()
            }
        }

        gate.addWaiter { finish() }

        guard let timeoutMs else { return }

        DispatchQueue.global().asyncAfter(
            deadline: .now() + .milliseconds(timeoutMs)
        ) {
            gate.completedSnapshot { completedNow in
                if completedNow { return }
                stateQ.async {
                    if didFinish { return }
                    didFinish = true
                    event(function, event: sdkInitWaitingExpired)
                    completion()
                }
            }
        }
    }
}

/// Runs a block only after initialization is ready.
///
/// This helper waits for the provided gate (or the current gate if `nil`) and then executes `block`.
/// If waiting times out, `block` is executed anyway.
///
/// - Parameters:
///   - function: Logical source tag used for event logging.
///   - gate: Optional `InitGate` snapshot to wait for. If `nil`, uses `InitBarrier.shared.current()`.
///   - block: Closure executed after the gate completes or the timeout expires.
internal func withInitReady(
    function: String,
    gate: InitGate? = nil,
    block: @escaping () -> Void
) {
    let g = gate ?? InitBarrier.shared.current()
    awaitInit(function: function, gate: g) {
        block()
    }
}

