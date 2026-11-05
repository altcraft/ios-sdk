//
//  AccessToBackgroundTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore

/**
 * AccessToBackgroundTests
 *
 * Positive scenarios:
 * - test_1: concurrent accessToBackground() calls begin exactly one background task.
 * - test_2: endBackgroundTask ends the begun identifier once; repeated end is a no-op.
 * - test_3: rescheduling the auto-end timer does not end the task prematurely.
 * - test_4: an .invalid begin result stores nothing and the next call can begin again.
 * - test_5: the expiration handler ends the currently active task.
 *
 */
final class AccessToBackgroundTests: IsolatedTestCase {

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

    /// test_1: concurrent accessToBackground() calls begin exactly one
    /// background task
    func test_1_concurrentAccess_beginsSingleTask() async throws {
        let provider = ScriptedBackgroundProvider()
        let background = AccessToBackground(provider: provider)

        try await withTimeout {
            await withTaskGroup(of: Void.self) { group in
                for _ in 0..<20 {
                    group.addTask { await background.accessToBackground() }
                }
            }
        }

        XCTAssertEqual(provider.recorded.beginCount, 1)
        XCTAssertEqual(provider.issuedIDs.count, 1)
    }

    /// test_2: endBackgroundTask ends the begun identifier once; repeated
    /// end is a no-op
    func test_2_end_endsBegunIdOnce_repeatedEndIsNoOp() async throws {
        let provider = ScriptedBackgroundProvider()
        let background = AccessToBackground(provider: provider)

        await background.accessToBackground()

        XCTAssertEqual(provider.recorded.beginCount, 1)
        let begunID = try XCTUnwrap(provider.issuedIDs.first)

        await background.endBackgroundTask()
        await background.endBackgroundTask()

        XCTAssertEqual(provider.recorded.endCalls, [begunID])
    }

    /// test_3: rescheduling the auto-end timer does not end the task
    /// prematurely
    func test_3_reschedule_doesNotEndTaskPrematurely() async throws {
        let provider = ScriptedBackgroundProvider()
        let background = AccessToBackground(provider: provider)

        await background.accessToBackground()

        // Let the first auto-end timer enter its long sleep.
        try await Task.sleep(nanoseconds: 200_000_000)

        // A second call reschedules the timer, cancelling the first one.
        await background.accessToBackground()

        // Give the cancelled timer a chance to (wrongly) end the task.
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(provider.recorded.endCalls.count, 0)
    }

    /// test_4: an .invalid begin result stores nothing and the next call
    /// can begin again
    func test_4_invalidBegin_storesNothing_andAllowsRetry() async throws {
        let provider = ScriptedBackgroundProvider()
        let background = AccessToBackground(provider: provider)

        provider.beginResult = .invalid
        await background.accessToBackground()

        XCTAssertEqual(provider.recorded.beginCount, 1)
        XCTAssertEqual(provider.recorded.endCalls.count, 0)

        provider.beginResult = nil
        await background.accessToBackground()

        XCTAssertEqual(provider.recorded.beginCount, 2)
        XCTAssertEqual(provider.issuedIDs.count, 1)

        await background.endBackgroundTask()
        XCTAssertEqual(provider.recorded.endCalls.count, 1)
    }

    /// test_5: the expiration handler ends the currently active task
    func test_5_expirationHandler_endsCurrentTask() async throws {
        let provider = ScriptedBackgroundProvider()
        let background = AccessToBackground(provider: provider)

        await background.accessToBackground()

        let begunID = try XCTUnwrap(provider.issuedIDs.first)
        provider.fireExpiration()

        // The handler spawns an unstructured task; let it run.
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(provider.recorded.endCalls, [begunID])
    }
}

// MARK: - Test Double

/// Timeout error used by background task tests.
private struct TestTimeoutError: Error {}

/// Scripted provider reproducing begin/end interactions with the background
/// task system.
private final class ScriptedBackgroundProvider: BackgroundTaskProviding, @unchecked Sendable {

    private let lock = NSLock()

    private(set) var beginCount = 0
    private(set) var endCalls: [UIBackgroundTaskIdentifier] = []
    private(set) var issuedIDs: [UIBackgroundTaskIdentifier] = []

    /// Expiration handler captured from the most recent begin.
    private var lastExpirationHandler: (@Sendable () -> Void)?

    /// When non-nil, begin returns this identifier instead of a fresh one.
    var beginResult: UIBackgroundTaskIdentifier?

    private var nextRawID: Int = 1

    func begin(
        name: String,
        expirationHandler: @escaping @Sendable () -> Void
    ) async -> UIBackgroundTaskIdentifier {
        lock.lock()
        beginCount += 1
        lastExpirationHandler = expirationHandler

        let id: UIBackgroundTaskIdentifier
        if let forced = beginResult {
            id = forced
        } else {
            id = UIBackgroundTaskIdentifier(rawValue: nextRawID)
            nextRawID += 1
            issuedIDs.append(id)
        }
        lock.unlock()

        return id
    }

    func end(_ id: UIBackgroundTaskIdentifier) async {
        lock.lock()
        endCalls.append(id)
        lock.unlock()
    }

    /// Invokes the expiration handler captured by the last begin.
    func fireExpiration() {
        lock.lock()
        let handler = lastExpirationHandler
        lock.unlock()
        handler?()
    }

    /// Snapshot of the recorded call counts.
    var recorded: (beginCount: Int, endCalls: [UIBackgroundTaskIdentifier]) {
        lock.lock()
        defer { lock.unlock() }
        return (beginCount, endCalls)
    }
}
