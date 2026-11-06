//
//  QueueWorker.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Common contract for SDK background operations that process pending
/// queue items.
///
/// Mirrors the Android `XWorker` concept: modules implement the operation and
/// the SDK dispatch loop (initialization phase or the background refresh task)
/// invokes ``processPending(enableRetry:)`` without depending on the concrete
/// module internals.
@_spi(_Altcraft) public protocol AltcraftBackgroundOperation {
    /// Processes pending operations for the module queue.
    ///
    /// - Parameter enableRetry: If `true`, a failed operation schedules a local
    ///   retry; if `false`, failures are dropped without scheduling a retry.
    func processPending(enableRetry: Bool) async
}

@_spi(_Altcraft) public extension AltcraftBackgroundOperation {
    /// Processes pending operations awaiting their completion.
    ///
    /// Called by the background refresh task instead of
    /// ``AltcraftBackgroundOperation/processPending(enableRetry:)``: once the
    /// system background task is marked complete the app may be suspended,
    /// so work that only enqueues asynchronously would never run. Modules
    /// whose pipelines enqueue asynchronously override this to await the
    /// enqueued processing; an offline snapshot check must not consume a
    /// processing attempt.
    ///
    /// Default implementation delegates to ``processPending(enableRetry:)``.
    ///
    /// - Parameter enableRetry: If `true`, a failed operation schedules a local
    ///   retry; if `false`, failures are dropped without scheduling a retry.
    func processPendingAwaited(enableRetry: Bool) async {
        await processPending(enableRetry: enableRetry)
    }
}

/// A single queue worker per module.
///
/// The module registry and the background refresh task dispatch work over the
/// registered queue workers without knowing the module internals.
@_spi(_Altcraft) public protocol QueueWorker: AltcraftBackgroundOperation {}
