//
//  InitBarrier.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Single initialization round gate.
@_spi(_Altcraft) public actor InitGate {
    private var isCompleted = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// Suspends until the gate is completed.
    ///
    /// Returns immediately when the task is already cancelled or becomes
    /// cancelled before the continuation is registered; otherwise a
    /// pre-cancellation race would leave the continuation unreferenced
    /// by the `onCancel` handler and the caller would hang forever.
    func wait() async {
        if isCompleted || Task.isCancelled { return }

        let waiterID = UUID()

        await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                if isCompleted || Task.isCancelled {
                    cont.resume()
                } else {
                    waiters[waiterID] = cont
                }
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(waiterID)
            }
        }
    }

    /// Marks the gate as completed and releases all waiters.
    func complete() {
        guard !isCompleted else { return }

        isCompleted = true
        let toResume = waiters.values
        waiters.removeAll(keepingCapacity: true)
        toResume.forEach { $0.resume() }
    }

    /// Returns the current completion state.
    func completed() -> Bool {
        isCompleted
    }

    /// Resumes the waiter registered under the given identifier.
    ///
    /// - Parameter id: Identifier returned when the waiter was registered.
    private func cancelWaiter(_ id: UUID) {
        guard let cont = waiters.removeValue(forKey: id) else { return }
        cont.resume()
    }
}

/// Manages the current initialization gate and rounds.
@_spi(_Altcraft) public actor InitBarrier {
    public static let shared = InitBarrier()

    private var gate = InitGate()
    /// Mirrors the current gate's completion state so that ``reserve()``
    /// can check-and-swap without suspension; an `await gate.completed()`
    /// here would let a concurrent reserve interleave and orphan the gate.
    private var gateCompleted = false

    private init() {}

    /// Returns the current gate snapshot.
    public func current() -> InitGate {
        gate
    }

    /// Returns the active gate or creates a new one if the previous is completed.
    ///
    /// Fully synchronous: the completed-state mirror removes the suspension
    /// point between the check and the swap, so concurrent callers cannot
    /// interleave and create orphaned gates.
    public func reserve() -> InitGate {
        if gateCompleted {
            gate = InitGate()
            gateCompleted = false
        }
        return gate
    }

    /// Completes the given gate.
    func complete(_ gate: InitGate) async {
        await gate.complete()
        if gate === self.gate {
            gateCompleted = true
        }
    }

    /// Replaces the current gate with a fresh one.
    ///
    /// Used by ``ModuleLifecycle/onSdkClear()`` so that a subsequent SDK
    /// initialization starts with a clean gate.
    func reset() {
        gate = InitGate()
        gateCompleted = false
    }
}

/// Waits for gate completion with optional timeout.
///
/// - Parameters:
///   - function: Logical source tag used for event logging.
///   - gate: Gate to wait for. Defaults to current snapshot.
///   - timeoutMs: Timeout in milliseconds (7 seconds default, Android
///     parity). Pass `nil` to wait indefinitely.
internal func awaitInit(
    function: String,
    gate: InitGate? = nil,
    timeoutMs: Int? = 7_000
) async {
    let g: InitGate

    if let gate {
        g = gate
    } else {
        g = await InitBarrier.shared.current()
    }

    if await g.completed() { return }

    if let timeoutMs {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await g.wait() }
            group.addTask {
                let ns = UInt64(timeoutMs) * 1_000_000
                try? await Task.sleep(nanoseconds: ns)
            }
            _ = await group.next()
            group.cancelAll()
        }

        if !(await g.completed()) {
            CoreLog.event(
                function,
                event: CoreEvents.sdkInitWaitingExpired
            )
        }
    } else {
        await g.wait()
    }
}

/// Executes `block` after init is ready (or timeout).
///
/// - Parameters:
///   - function: Logical source tag used for event logging.
///   - gate: Optional gate snapshot. If `nil`, uses current gate.
///   - timeoutMs: Timeout in milliseconds (7 seconds default, Android
///     parity). Pass `nil` to wait indefinitely.
///   - block: Closure executed after completion or timeout.
@_spi(_Altcraft) public func withInitReady(    function: String,
    gate: InitGate? = nil,
    timeoutMs: Int? = 7_000,
    block: @Sendable @escaping () async -> Void
) async {
    await awaitInit(function: function, gate: gate, timeoutMs: timeoutMs)
    await block()
}
