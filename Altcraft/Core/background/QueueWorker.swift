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

/// A single queue worker per module.
///
/// The module registry and the background refresh task dispatch work over the
/// registered queue workers without knowing the module internals.
@_spi(_Altcraft) public protocol QueueWorker: AltcraftBackgroundOperation {}
