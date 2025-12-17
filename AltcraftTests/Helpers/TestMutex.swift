//
//  UserDefaultsIsolation.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//  © 2025 Altcraft. All rights reserved.

import Foundation

/// Inter-process mutex via `flock`.
/// Guarantees that only one test (or test suite) runs inside the critical section.
final class TestMutex {
    private let fd: Int32
    private let path: String

    init(name: String = "altcraft.tests.global.lock") {
        self.path = (NSTemporaryDirectory() as NSString).appendingPathComponent(name)

        let fd = open(self.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        precondition(fd != -1, "Failed to open lock file at \(self.path)")
        self.fd = fd
    }

    func lock() {
        let r = flock(fd, LOCK_EX)
        precondition(r == 0, "Failed to acquire flock on \(path)")
    }

    func unlock() {
        let r = flock(fd, LOCK_UN)
        precondition(r == 0, "Failed to release flock on \(path)")
    }

    deinit {
        close(fd)
    }
}

