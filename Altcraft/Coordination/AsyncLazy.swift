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
internal actor AsyncLazy<Value: Sendable> {
    
    /// Internal loading state of the async lazy cache.
    private enum State {
        case idle
        case loading(Task<Value?, Error>)
        case loaded(Value?)
    }
    
    private var state: State = .idle
    
    /// Returns the cached value if available, otherwise loads it once and shares
    /// the same in-flight task across concurrent callers.
    ///
    /// - Parameter loader: Async loader that produces the value to cache.
    /// - Returns: The cached or newly loaded value.
    func get(
        _ loader: @escaping @Sendable () async throws -> Value?
    ) async throws -> Value? {
        switch state {
        case .loaded(let value):return value
        case .loading(let task): return try await task.value
        case .idle:
            let task = Task<Value?, Error> {
                try await loader()
            }
            state = .loading(task)
            do {
                let value = try await task.value
                state = .loaded(value)
                return value
            } catch {
                state = .idle
                throw error
            }
        }
    }
    
    /// Clears the cached value and forgets any in-flight load result.
    ///
    /// Does not cancel an already running task.
    func reset() { state = .idle }
}
