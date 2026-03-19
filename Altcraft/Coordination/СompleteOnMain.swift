//
//  OnMain.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.


import Foundation

/// Calls `completion` on the main thread.
/// Works with both Sendable and non-Sendable payloads, ObjC-friendly.
func completeOnMain<T>(
    _ value: T,
    _ completion: @escaping (T) -> Void
) {
    if Thread.isMainThread {
        completion(value)
    } else {
        let box = ClosureBox {
            completion(value)
        }
        RunLoop.main.perform {
            box.invoke()
        }
    }
}

/// Void convenience.
func completeOnMain(_ completion: @escaping () -> Void) {
    if Thread.isMainThread {
        completion()
    } else {
        let box = ClosureBox(completion)
        RunLoop.main.perform {
            box.invoke()
        }
    }
}
