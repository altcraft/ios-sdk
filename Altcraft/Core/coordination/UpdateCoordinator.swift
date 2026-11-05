//
//  UpdateCoordinator.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Coalesces concurrent calls into a single in-flight async operation.
///
/// While an operation is running, additional callers wait for the same result.
/// Once finished, all waiters receive the shared result.
@_spi(_Altcraft) public actor UpdateCoordinator<Result: Sendable> {
    public init() {}

    private var inFlight: Task<Result, Never>?

    /// Runs `operation` once for all concurrent callers.
    ///
    /// If an operation is already running, waits for its result.
    ///
    /// - Parameter operation: Async operation producing a shared result.
    /// - Returns: The shared result.
    public func run(
        operation: @Sendable @escaping () async -> Result
    ) async -> Result {
        if let inFlight {
            return await inFlight.value
        }

        let task = Task { await operation() }
        inFlight = task

        let result = await task.value
        inFlight = nil

        return result
    }

    /// Callback compatibility.
    ///
    /// - Parameters:
    ///   - operation: Async operation producing a shared result.
    ///   - completion: Callback receiving the shared result.
    public func run(
        operation: @Sendable @escaping () async -> Result,
        completion: @escaping (Result) -> Void
    ) {
        Task {
            let result = await run(operation: operation)
            completion(result)
        }
    }

    /// Waits for the current in-flight operation result, if any.
    ///
    /// - Returns: The shared result, or `nil` if nothing is running.
    func waitIfRunning() async -> Result? {
        guard let task = inFlight else { return nil }
        return await task.value
    }
}
