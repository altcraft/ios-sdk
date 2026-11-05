//
//  AsyncLazy.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Thread-safe async lazy cache for Sendable values.
///
/// Caches both a loaded value and an explicit `nil`.
/// If multiple callers request the value concurrently, only one load is performed,
/// and the rest await the same in-flight task.
@_spi(_Altcraft) public actor AsyncLazy<Value: Sendable> {

    /// Internal loading state of the async lazy cache.
    private enum State {
        case idle
        case loading(Task<Value?, Error>)
        case loaded(Value?)
    }

    private var state: State = .idle

    /// Monotonic counter of resets guarding state writes.
    ///
    /// A load captures the generation when it starts. If the generation has
    /// changed by the time the load completes, a reset happened in between
    /// and the stale result must not be written into the cache.
    private var generation = 0

    /// Creates an empty cache (idle state).
    @_spi(_Altcraft) public init() {}

    /// Returns the cached value if available, otherwise loads it once and shares
    /// the same in-flight task across concurrent callers.
    ///
    /// - Parameter loader: Async loader that produces the value to cache.
    /// - Returns: The cached or newly loaded value.
    @_spi(_Altcraft) public func get(
        _ loader: @escaping @Sendable () async throws -> Value?
    ) async throws -> Value? {
        switch state {
        case .loaded(let value):return value
        case .loading(let task): return try await task.value
        case .idle:
            let generationAtStart = generation
            let task = Task<Value?, Error> {
                try await loader()
            }
            state = .loading(task)
            do {
                let value = try await task.value
                // A reset while this load was in flight makes the result
                // stale: return it to the caller without caching it.
                guard generation == generationAtStart else {
                    return value
                }
                state = .loaded(value)
                return value
            } catch {
                guard generation == generationAtStart else {
                    throw error
                }
                state = .idle
                throw error
            }
        }
    }

    /// Clears the cached value and forgets any in-flight load result.
    ///
    /// Does not cancel an already running task. The generation bump makes
    /// any in-flight load stale: its result is still returned to its caller
    /// but never written into the cache.
    @_spi(_Altcraft) public func reset() {
        generation += 1
        state = .idle
    }
}
