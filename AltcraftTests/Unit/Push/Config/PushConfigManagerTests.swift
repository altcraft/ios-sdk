//
//  PushConfigManagerTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
@testable import AltcraftPush

/**
 * PushConfigManagerTests
 *
 * Positive scenarios:
 * - test_1: setConfig persists before invalidating the cache, so a concurrent
 *   read racing inside the write window cannot leave a stale provider
 *   priority in the cache.
 * - test_2: clearCache removes persistence before invalidating the cache, so
 *   a concurrent read inside the delete window cannot resurrect removed data.
 * - test_3: setConfig followed by getConfig returns the saved configuration.
 *
 */
final class PushConfigManagerTests: IsolatedTestCase {

    // MARK: - Helpers

    /// Runs `body` and fails the test if it does not finish within 5 seconds.
    private func withTimeout<T: Sendable>(
        _ body: @escaping @Sendable () async -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw TestTimeoutError()
            }
            let first = try await group.next()!
            group.cancelAll()
            _ = try? await group.next()
            return first
        }
    }

    // MARK: - Tests

    /// test_1: setConfig persists before invalidating the cache, so a
    /// concurrent read racing inside the write window cannot leave a stale
    /// provider priority in the cache
    func test_1_setConfig_concurrentReadInWriteWindow_cannotCacheStalePriority() async throws {
        let old = PushConfiguration(providerPriority: ["ios-apns"])
        let new = PushConfiguration(providerPriority: ["ios-firebase"])
        let storage = ScriptedStorage(value: old)
        let manager = PushConfigManager(storage: storage)

        await storage.armBlock()
        let setTask = Task { await manager.setConfig(new) }
        await storage.waitWriteStarted()

        let during = await manager.getConfig()
        XCTAssertEqual(during.providerPriority, ["ios-apns"])

        await storage.releaseWrite()
        try await withTimeout { await setTask.value }

        let final = await manager.getConfig()
        XCTAssertEqual(final.providerPriority, ["ios-firebase"])
    }

    /// test_2: clearCache removes persistence before invalidating the cache,
    /// so a concurrent read inside the delete window cannot resurrect removed
    /// data
    func test_2_clearCache_concurrentReadInDeleteWindow_cannotResurrectRemovedData() async throws {
        let old = PushConfiguration(providerPriority: ["ios-apns"])
        let storage = ScriptedStorage(value: old)
        let manager = PushConfigManager(storage: storage)

        _ = await manager.getConfig()

        await storage.armBlock()
        let clearTask = Task { await manager.clearCache() }
        await storage.waitWriteStarted()

        let during = await manager.getConfig()
        XCTAssertEqual(during.providerPriority, ["ios-apns"])

        await storage.releaseWrite()
        try await withTimeout { await clearTask.value }

        let final = await manager.getConfig()
        XCTAssertEqual(final.providerPriority, [])
    }

    /// test_3: setConfig followed by getConfig returns the saved configuration
    func test_3_setConfig_thenGetConfig_returnsSavedConfiguration() async throws {
        let storage = ScriptedStorage(value: PushConfiguration(providerPriority: []))
        let manager = PushConfigManager(storage: storage)

        await manager.setConfig(PushConfiguration(providerPriority: ["ios-apns", "ios-firebase"]))

        let value = await manager.getConfig()
        XCTAssertEqual(value.providerPriority, ["ios-apns", "ios-firebase"])
    }
}

// MARK: - Supporting Types

/// Timeout error used by the local wait helper.
private struct TestTimeoutError: Error {}

/// Scripted storage reproducing the race window between a blocked write and
/// a concurrent cache load.
private actor ScriptedStorage: PushConfigStoring {

    /// Current stored value.
    private var value: PushConfiguration

    /// When set, the next write blocks until `releaseWrite()` is called.
    private var blockNextWrite = false

    /// Set once a write has started.
    private var writeStarted = false

    /// Continuations waiting for the write to start.
    private var writeStartedWaiters: [CheckedContinuation<Void, Never>] = []

    /// Gate suspending the blocked write.
    private var writeGate: CheckedContinuation<Void, Never>?

    /// Creates the storage with an initial value.
    init(value: PushConfiguration) {
        self.value = value
    }

    func get() async -> PushConfiguration { value }

    func set(_ config: PushConfiguration) async {
        signalWriteStarted()

        if blockNextWrite {
            blockNextWrite = false
            await gate()
        }

        value = config
    }

    func delete() async {
        signalWriteStarted()

        if blockNextWrite {
            blockNextWrite = false
            await gate()
        }

        value = PushConfiguration(providerPriority: [])
    }

    /// Blocks the next write until `releaseWrite()` is called.
    func armBlock() {
        blockNextWrite = true
    }

    /// Suspends until a write has started (entering the race window).
    func waitWriteStarted() async {
        if writeStarted { return }
        await withCheckedContinuation { cont in
            writeStartedWaiters.append(cont)
        }
    }

    /// Releases the blocked write.
    func releaseWrite() {
        writeGate?.resume()
        writeGate = nil
    }

    /// Signals all waiters that a write has started.
    private func signalWriteStarted() {
        writeStarted = true
        let waiters = writeStartedWaiters
        writeStartedWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    /// Suspends the current write on the gate.
    private func gate() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            writeGate = cont
        }
    }
}
