//
//  InitBarrier.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import Foundation

/// Single initialization round gate.
internal actor InitGate {

    private var isCompleted = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// Suspends until the gate is completed.
    func wait() async {
        if isCompleted { return }

        let waiterID = UUID()

        await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                if isCompleted {
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

    private func cancelWaiter(_ id: UUID) {
        guard let cont = waiters.removeValue(forKey: id) else { return }
        cont.resume()
    }
}

/// Manages the current initialization gate and rounds.
internal actor InitBarrier {
    static let shared = InitBarrier()

    private var gate = InitGate()

    private init() {}

    /// Returns the current gate snapshot.
    func current() -> InitGate {
        gate
    }

    /// Returns the active gate or creates a new one if the previous is completed.
    func reserve() async -> InitGate {
        if await gate.completed() {
            gate = InitGate()
        }
        return gate
    }

    /// Completes the given gate.
    func complete(_ gate: InitGate) async {
        await gate.complete()
    }
}

/// Waits for gate completion with optional timeout.
///
/// - Parameters:
///   - function: Logical source tag used for event logging.
///   - gate: Gate to wait for. Defaults to current snapshot.
///   - timeoutMs: Timeout in milliseconds. Pass `nil` to wait indefinitely.
internal func awaitInit(
    function: String,
    gate: InitGate? = nil,
    timeoutMs: Int? = 5_000
) async {
    let g: InitGate

    if let gate {
        g = gate
    } else {
        g = await InitBarrier.shared.current()
    }

    if await g.completed() { return }

    event(function, event: initAwait)

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
            event(function, event: sdkInitWaitingExpired)
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
///   - timeoutMs: Timeout in milliseconds. Pass `nil` to wait indefinitely.
///   - block: Closure executed after completion or timeout.
internal func withInitReady(
    function: String,
    gate: InitGate? = nil,
    timeoutMs: Int? = 5_000,
    block: @Sendable @escaping () async -> Void
) async {
    await awaitInit(function: function, gate: gate, timeoutMs: timeoutMs)
    await block()
}
