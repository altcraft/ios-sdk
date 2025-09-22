//
//  NetworkMonitor.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Network

/// A singleton class responsible for monitoring the network connection status and performing actions once the device is connected.
///
/// This class uses `NWPathMonitor` to detect network availability and executes any queued actions as soon as the network becomes available.
final class NetworkMonitor {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private var isConnected: Bool
    private var retryActions: [() -> Void] = []

    /// The shared instance of `NetworkMonitor`.
    public static let shared = NetworkMonitor()

    /// Initializes the network monitor and starts observing network status changes.
    private init() {
        self.isConnected = monitor.currentPath.status == .satisfied

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            if path.status == .satisfied {
                self.isConnected = true
                let actions = self.retryActions
                self.retryActions.removeAll()

                DispatchQueue.main.async {
                    actions.forEach { $0() }
                }
            } else {
                self.isConnected = false
            }
        }

        monitor.start(queue: queue)
    }

    /// Executes the provided action when network connectivity is available.
    ///
    /// If the device is already online, the action is executed immediately.
    /// Otherwise, it is queued and executed once connectivity is restored.
    ///
    /// - Parameter action: A closure to run once the device is online.
    func performActionWhenConnected(action: @escaping () -> Void) {
        if isConnected {
            DispatchQueue.main.async {
                action()
            }
        } else {
            retryActions.append(action)
        }
    }
}

