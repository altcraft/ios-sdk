//
//  AltcraftInitTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
@testable import Altcraft

/**
 * AltcraftInitTests
 *
 * Positive scenarios:
 *  - test_1: initSDK with nil configuration → returns false and emits error event.
 *  - test_2: initSDK with valid configuration → returns result and emits configSet on success or error event on failure.
 *
 */
final class AltcraftInitTests: IsolatedTestCase {

    private let appGroupPrefix = "group.altcraft.tests.init."
    private let apiURLString = "https://api.example.com"
    private let rTokenString = "R-TOKEN"

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
        await StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
        StoredVariablesManager.shared.setCritDB(value: false)
    }

    override func tearDown() async throws {
        await StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
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
        guard let configuration = AltcraftConfiguration.Builder()
            .setApiUrl(apiURLString)
            .setRToken(rTokenString)
            .setAppInfo(nil)
            .setProviderPriorityList([])
            .build() else {
            XCTFail("Failed to build minimal AltcraftConfiguration")
            fatalError("AltcraftConfiguration.Builder returned nil")
        }

        return configuration
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

    /// test_1: initSDK with nil configuration returns false and emits error event
    func test_1_initSDK_withNilConfiguration_returnsFalse_andEmitsErrorEvent() async {
        let spy = EventSpy()
        spy.start()
        defer { spy.stop() }

        let result = await AltcraftInit.shared.initSDK(configuration: nil)

        let hasErrorEvent = await waitForEvent(in: spy) { event in
            event is ErrorEvent
        }

        XCTAssertFalse(result)
        XCTAssertTrue(hasErrorEvent)
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
                event.eventCode == configSet.0 || (event.message ?? "").contains(configSet.1)
            }

            XCTAssertTrue(hasConfigSet)
        } else {
            let hasErrorEvent = await waitForEvent(in: spy) { event in
                event is ErrorEvent
            }

            XCTAssertTrue(hasErrorEvent)
        }
    }
}
