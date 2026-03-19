//
//  NetworkMonitor.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Network
import Foundation

/// A singleton actor responsible for monitoring the network connection status and performing actions once the device is connected.
///
/// This actor uses `NWPathMonitor` to detect network availability and releases any waiters as soon as the network becomes available.
actor NetworkMonitor {

    /// The shared instance of `NetworkMonitor`.
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)

    private var isConnected: Bool
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Initializes the network monitor and starts observing network status changes.
    private init() {
        self.isConnected = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task { await self.handle(path: path) }
        }

        monitor.start(queue: queue)
    }

    /// Suspends until network connectivity is available.
    ///
    /// If the device is already online, returns immediately.
    func waitConnected() async {
        if isConnected { return }

        await withCheckedContinuation { cont in
            if isConnected { cont.resume() }
            else { waiters.append(cont) }
        }
    }

    /// Executes the provided async action when network connectivity is available.
    ///
    /// If the device is already online, the action is executed immediately.
    /// Otherwise, it is awaited and executed once connectivity is restored.
    ///
    /// - Parameter action: An async closure to run once the device is online.
    func performWhenConnected(_ action: @Sendable @escaping () async -> Void) async {
        await waitConnected()
        await action()
    }

    /// Returns current connectivity snapshot.
    func connected() -> Bool { isConnected }

    /// Handles updates from `NWPathMonitor`.
    private func handle(path: NWPath) {
        let nowConnected = (path.status == .satisfied)

        if nowConnected {
            isConnected = true

            let current = waiters
            waiters.removeAll(keepingCapacity: true)
            current.forEach { $0.resume() }
        } else {
            isConnected = false
        }
    }
}
