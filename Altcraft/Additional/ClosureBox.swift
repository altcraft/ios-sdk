//
//  ClosureBox.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.
//

/// Universal box to carry non-Sendable closures across Sendable boundaries.
/// Correctness is ensured by invoking `invoke()` on the intended thread/queue.
final class ClosureBox: @unchecked Sendable {
    private let closure: () -> Void

    init(_ closure: @escaping () -> Void) {
        self.closure = closure
    }
    func invoke() { closure() }
}

/// Universal box to carry a callback across Sendable boundaries.
final class CallbackBox<T>: @unchecked Sendable {
    private let cb: (T) -> Void
    init(_ cb: @escaping (T) -> Void) { self.cb = cb }
    func call(_ value: T) { cb(value) }
}

/// A small container to carry non-Sendable values through `@Sendable` closures.
/// Use only when you fully control thread/queue usage and know it is safe.
final class UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
