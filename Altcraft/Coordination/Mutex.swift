//
//  Mutex.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import Foundation

final class Mutex {
    private let q = DispatchQueue(label: "com.altcraft.sdk.mutex", qos: .userInitiated)
    private var pending: [(@escaping () -> Void) -> Void] = []
    private var locked = false

    func lock(_ work: @escaping (_ unlock: @escaping () -> Void) -> Void) {
        q.async {
            if self.locked {
                self.pending.append(work)
                return
            }
            self.locked = true
            self.run(work)
        }
    }

    private func run(_ work: @escaping (_ unlock: @escaping () -> Void) -> Void) {
        work { [weak self] in
            guard let self else { return }
            self.q.async {
                if self.pending.isEmpty {
                    self.locked = false
                    return
                }
                let next = self.pending.removeFirst()
                self.run(next)
            }
        }
    }
}
