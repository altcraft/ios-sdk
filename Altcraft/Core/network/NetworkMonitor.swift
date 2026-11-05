//
//  NetworkMonitor.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Network
import Foundation

/// A singleton actor responsible for monitoring the network connection status and performing actions once the device is connected.
///
/// This actor uses `NWPathMonitor` to detect network availability and releases any waiters as soon as the network becomes available.
/// A waiting task is released immediately when the task itself is cancelled;
/// its continuation is removed from the waiter list and resumed, so a
/// cancelled task never remains suspended until connectivity returns.
@_spi(_Altcraft) public actor NetworkMonitor {
    /// The shared instance of `NetworkMonitor`.
    public static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    private var isConnected: Bool

    /// Tasks suspended until connectivity becomes available, keyed by a
    /// unique identifier used to finalize the wait on task cancellation.
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    /// Identifiers of tasks whose cancellation arrived before their
    /// continuation was registered (cancellation won the race).
    private var cancelledIDs: Set<UUID> = []

    /// Initializes the network monitor and starts observing network status changes.
    /// Initializes the network monitor and starts observing network status changes.
    ///
    /// - Parameter startMonitor: When `false`, the real `NWPathMonitor` is
    ///   not started and connectivity stays offline; used by unit tests to
    ///   drive connectivity explicitly.
    init(startMonitor: Bool = true) {
        let satisfied = monitor.currentPath.status == .satisfied
        self.isConnected = startMonitor && satisfied

        guard startMonitor else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.handle(path: path) }
        }

        monitor.start(queue: queue)
    }

    /// Suspends until network connectivity is available.
    ///
    /// If the device is already online, returns immediately. If the calling
    /// task is cancelled while waiting, the waiter is removed and resumed
    /// right away; the task observes the cancellation through
    /// `Task.isCancelled` after the call returns.
    public func waitConnected() async {
        if isConnected { return }

        let id = UUID()

        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                if isConnected {
                    cont.resume()
                    return
                }

                waiters[id] = cont

                // Cancellation may fire before the continuation is stored;
                // finalize the wait immediately in that case.
                if cancelledIDs.remove(id) != nil {
                    waiters.removeValue(forKey: id)
                    cont.resume()
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
    }

    /// Executes the provided async action when network connectivity is available.
    ///
    /// If the device is already online, the action is executed immediately.
    /// Otherwise, it is awaited and executed once connectivity is restored.
    /// A cancelled task skips the action entirely.
    ///
    /// - Parameter action: An async closure to run once the device is online.
    public func performWhenConnected(_ action: @Sendable @escaping () async -> Void) async {
        await waitConnected()

        guard !Task.isCancelled else { return }

        await action()
    }

    /// Returns current connectivity snapshot.
    func connected() -> Bool { isConnected }

    /// Handles updates from `NWPathMonitor`.
    private func handle(path: NWPath) {
        setConnected(path.status == .satisfied)
    }

    /// Updates connectivity and, when online, releases all pending waiters.
    private func setConnected(_ value: Bool) {
        isConnected = value

        guard value else { return }

        let current = waiters
        waiters.removeAll(keepingCapacity: true)
        // All waiters have been resumed; pending cancellations are moot.
        cancelledIDs.removeAll()
        current.values.forEach { $0.resume() }
    }

    /// Cancels a pending waiter, resuming its continuation immediately.
    ///
    /// If the waiter has not been registered yet (cancellation raced ahead of
    /// the registration), the identifier is remembered so the registration
    /// path finalizes the wait without suspending.
    private func cancelWaiter(id: UUID) {
        if let continuation = waiters.removeValue(forKey: id) {
            continuation.resume()
            return
        }

        if !isConnected {
            cancelledIDs.insert(id)
        }
    }
}

// MARK: - Unit Test Hooks

/// Extension exposing internal state manipulation hooks for unit tests.
extension NetworkMonitor {

    /// Test hook that overrides connectivity and behaves like a network
    /// update: switching online releases all pending waiters.
    ///
    /// - Parameter value: Connectivity value to set.
    func test_setConnected(_ value: Bool) {
        setConnected(value)
    }

    /// Test hook returning the number of tasks currently waiting for
    /// connectivity.
    ///
    /// - Returns: Pending waiter count.
    func test_waiterCount() -> Int {
        waiters.count
    }
}
