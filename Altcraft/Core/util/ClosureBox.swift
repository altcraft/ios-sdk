//
//  ClosureBox.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation

/// Universal box to carry non-Sendable closures across Sendable boundaries.
/// Correctness is ensured by invoking `invoke()` on the intended thread/queue.
@_spi(_Altcraft) public final class ClosureBox: @unchecked Sendable {
    private let closure: () -> Void

    public init(_ closure: @escaping () -> Void) {
        self.closure = closure
    }
    /// Invokes the boxed closure on the calling queue.
    public func invoke() { closure() }
}

/// Universal box to carry a callback across Sendable boundaries.
@_spi(_Altcraft) public final class CallbackBox<T>: @unchecked Sendable {
    private let cb: (T) -> Void
    public init(_ cb: @escaping (T) -> Void) { self.cb = cb }
    /// Invokes the boxed callback with the given value.
    ///
    /// - Parameter value: Value passed to the callback.
    public func call(_ value: T) { cb(value) }
}

/// A small container to carry non-Sendable values through `@Sendable` closures.
/// Use only when you fully control thread/queue usage and know it is safe.
@_spi(_Altcraft) public final class UncheckedSendableBox<T>: @unchecked Sendable {
    public let value: T
    public init(_ value: T) { self.value = value }
}
