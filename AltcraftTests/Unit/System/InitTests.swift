//
//  InitTests.swift
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
 * AltcraftInitTests
 *
 * Positive scenarios:
 *  - test_1: initSDK with an invalid configuration → returns false, deletes the
 *    stored configuration and emits the setup error event.
 *  - test_2: initSDK with valid configuration → returns result and emits configSet on success or error event on failure.
 *  - test_3: initSDK with a blank rToken → returns false and emits the setup error event.
 *
 */
final class AltcraftInitTests: IsolatedTestCase {

    private let appGroupPrefix = "group.altcraft.tests.init."
    private let apiURLString = "https://api.example.com"
    private let rTokenString = "R-TOKEN"

    /// Captures emitted SDK events.
    private final class EventSpy {
        private let lock = NSLock()
        private(set) var events: [Event] = []
        private var isStarted = false

        func start() {
            guard !isStarted else { return }
            isStarted = true

            SDKEvents.shared.subscribe { [weak self] event in
                guard let self else { return }
                self.lock.lock()
                self.events.append(event)
                self.lock.unlock()
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
            isStarted = false
        }

        func snapshot() -> [Event] {
            lock.lock()
            defer { lock.unlock() }
            return events
        }

        func contains(where predicate: (Event) -> Bool) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return events.contains(where: predicate)
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        isolateUserDefaults()
        await clearProviders()
        await PushStoredVariables.shared.clearManualToken()
        PushStoredVariables.shared.clearSavedToken()
        StoredVariablesManager.shared.setCritDB(value: false)
    }

    override func tearDown() async throws {
        await PushStoredVariables.shared.clearManualToken()
        PushStoredVariables.shared.clearSavedToken()
        await clearProviders()
        StoredVariablesManager.shared.setCritDB(value: false)
        try await super.tearDown()
    }

    private func isolateUserDefaults() {
        StoredVariablesManager.shared.setGroupsName(
            value: appGroupPrefix + UUID().uuidString
        )
    }

    private func clearProviders() async {
        await TokenManager.shared.setFCMProvider(nil)
        await TokenManager.shared.setHMSProvider(nil)
        await TokenManager.shared.setAPNSProvider(nil)
    }

    private func makeMinimalConfig() -> AltcraftConfiguration {
        AltcraftConfiguration.Builder(
            apiUrl: apiURLString,
            rToken: rTokenString
        )
        .build()
    }

    /**
     * Waits until the event spy contains an event matching the predicate
     * or until timeout is reached.
     *
     * - Parameters:
     *   - spy: Event storage observer.
     *   - timeoutNanoseconds: Max waiting time.
     *   - pollNanoseconds: Polling interval.
     *   - predicate: Event matching condition.
     * - Returns: `true` if matching event appeared in time, otherwise `false`.
     */
    private func waitForEvent(
        in spy: EventSpy,
        timeoutNanoseconds: UInt64 = 1_000_000_000,
        pollNanoseconds: UInt64 = 20_000_000,
        predicate: @escaping (Event) -> Bool
    ) async -> Bool {
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if spy.contains(where: predicate) {
                return true
            }

            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }

        return spy.contains(where: predicate)
    }

    /// test_1: initSDK with an invalid configuration returns false, deletes the
    /// stored configuration and emits the setup error event
    func test_1_initSDK_withInvalidConfiguration_returnsFalse_deletesStoredConfig_andEmitsErrorEvent() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        // Seeds a stored configuration so the deletion can be verified.
        let seeded = await ConfigManager.shared.setConfig(makeMinimalConfig())
        XCTAssertTrue(seeded)

        let invalid = AltcraftConfiguration.Builder(apiUrl: "   ")
            .build()

        let result = await AltcraftInit.shared.initSDK(configuration: invalid)

        let hasErrorEvent = await waitForEvent(in: spy) { event in
            guard let errorEvent = event as? ErrorEvent else { return false }
            return (errorEvent.event as? CoreEvents) == .invalidUrlValue
        }

        let storedExists = await CoreConfigDao().exists()

        XCTAssertFalse(result)
        XCTAssertTrue(hasErrorEvent)
        XCTAssertFalse(
            storedExists,
            "Invalid configuration must delete the stored configuration entity"
        )
    }

    /// test_2: initSDK with valid configuration returns result and emits configSet on success or error event on failure
    func test_2_initSDK_withValidConfiguration_returnsResult_andEmitsConfigSetOnSuccess_orErrorEventOnFailure() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let configuration = makeMinimalConfig()
        let result = await AltcraftInit.shared.initSDK(configuration: configuration)

        if result {
            let hasConfigSet = await waitForEvent(in: spy) { event in
                (event.event as? CoreEvents) == .configSet ||
                (event.message ?? "").contains(CoreEvents.configSet.message)
            }

            XCTAssertTrue(hasConfigSet)
        } else {
            let hasErrorEvent = await waitForEvent(in: spy) { event in
                event is ErrorEvent
            }

            XCTAssertTrue(hasErrorEvent)
        }
    }

    /// test_3: initSDK with a blank rToken returns false and emits the setup error event
    func test_3_initSDK_withBlankRToken_returnsFalse_andEmitsErrorEvent() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let invalid = AltcraftConfiguration.Builder(
            apiUrl: apiURLString,
            rToken: "   "
        )
        .build()

        let result = await AltcraftInit.shared.initSDK(configuration: invalid)

        let hasErrorEvent = await waitForEvent(in: spy) { event in
            guard let errorEvent = event as? ErrorEvent else { return false }
            return (errorEvent.event as? CoreEvents) == .invalidRTokenValue
        }

        XCTAssertFalse(result)
        XCTAssertTrue(hasErrorEvent)
    }
}
