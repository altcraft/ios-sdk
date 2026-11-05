//
//  TestMutex.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import Foundation
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

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

