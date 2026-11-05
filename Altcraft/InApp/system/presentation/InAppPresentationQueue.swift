//
//  InAppPresentationQueue.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/// Serializes in-app presentations.
@available(iOSApplicationExtension, unavailable)
actor InAppPresentationQueue {

    /// Shared queue instance.
    static let shared = InAppPresentationQueue()

    private var isPresenting = false

    /// A task suspended until the presentation slot becomes available.
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    /// Suspended tasks in FIFO order; the identifier finalizes the wait on
    /// task cancellation.
    private var waiters: [Waiter] = []

    /// Identifiers of tasks whose cancellation arrived before their
    /// continuation was registered (cancellation won the race).
    private var cancelledIDs: Set<UUID> = []

    private init() {}

    /// Suspends the calling task until no in-app is currently being presented.
    ///
    /// When the slot becomes available, the task resumes and claims the slot.
    /// Only one task can hold the slot at a time.
    ///
    /// A waiting task is released immediately when the task itself is
    /// cancelled; its entry is removed from the waiter list and its
    /// continuation resumed with `granted == false`, so a cancelled task
    /// never remains suspended until the current presentation ends and never
    /// claims a slot that still belongs to an active presentation.
    func waitForTurn() async {
        if !isPresenting {
            isPresenting = true
            return
        }

        let id = UUID()

        let granted = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                // Cancellation may fire before the continuation is stored;
                // finalize the wait immediately in that case.
                if cancelledIDs.remove(id) != nil {
                    continuation.resume(returning: false)
                    return
                }

                waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }

        guard granted else { return }

        isPresenting = true
    }

    /// Releases the current presentation slot and resumes the next waiting task.
    ///
    /// If no tasks are waiting, the slot becomes idle.
    func finishPresentation() {
        guard !waiters.isEmpty else {
            isPresenting = false
            return
        }

        let next = waiters.removeFirst()
        next.continuation.resume(returning: true)
    }

    /// Cancels a pending waiter, resuming its continuation immediately.
    ///
    /// The waiter is resumed with `granted == false` so it does not claim
    /// the slot of the still-active presentation.
    ///
    /// If the waiter has not been registered yet (cancellation raced ahead of
    /// the registration), the identifier is remembered so the registration
    /// path finalizes the wait without suspending.
    private func cancelWaiter(id: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(returning: false)
            return
        }

        cancelledIDs.insert(id)
    }
}

// MARK: - Unit Test Hooks

extension InAppPresentationQueue {

    /// Test hook returning the number of tasks currently waiting for the
    /// presentation slot.
    ///
    /// - Returns: Pending waiter count.
    func test_waiterCount() -> Int {
        waiters.count
    }
}
