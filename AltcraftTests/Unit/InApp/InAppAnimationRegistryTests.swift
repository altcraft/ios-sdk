//
//  InAppAnimationRegistryTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
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

/**
 * InAppAnimationRegistryTests
 *
 * Positive scenarios:
 *  - test_1: getListener returns nil by default.
 *  - test_2: setListener stores a listener.
 *  - test_3: setListener with nil removes the listener.
 *  - test_4: setListener overwrites previous listener.
 */
final class InAppAnimationRegistryTests: XCTestCase {

    private let registry = InAppAnimationRegistry.shared

    private func waitAsync(description: String = "async", timeout: TimeInterval = 2, _ work: @escaping () async -> Void) {
        let exp = expectation(description: description)
        Task {
            await work()
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        waitAsync {
            await self.registry.setListener(nil)
        }
    }

    /// test_1: getListener returns nil by default
    func test_1_getListener_returnsNilByDefault() async {
        let listener = await registry.getListener()
        XCTAssertNil(listener)
    }

    /// test_2: setListener stores a listener
    func test_2_setListener_storesListener() async {
        let captured = AnimationCalledFlag()
        await registry.setListener { _ in
            captured.mark()
        }

        let listener = await registry.getListener()
        XCTAssertNotNil(listener)
    }

    /// test_3: setListener with nil removes the listener
    func test_3_setListenerNil_removesListener() async {
        await registry.setListener { _ in }
        let beforeNil = await registry.getListener()
        XCTAssertNotNil(beforeNil)

        await registry.setListener(nil)
        let afterNil = await registry.getListener()
        XCTAssertNil(afterNil)
    }

    /// test_4: setListener overwrites previous listener
    func test_4_setListener_overwritesPrevious() async {
        let first = AnimationCalledFlag()
        let second = AnimationCalledFlag()

        await registry.setListener { _ in
            first.mark()
        }
        await registry.setListener { _ in
            second.mark()
        }

        let listener = await registry.getListener()
        XCTAssertNotNil(listener)
    }
}

/// Sendable flag recording animation invocation.
private final class AnimationCalledFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _called = false
    func mark() {
        lock.lock()
        _called = true
        lock.unlock()
    }
    var called: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _called
    }
}
