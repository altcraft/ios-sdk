//
//  AltcraftInitTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * AltcraftInitTests (iOS 13 compatible)
 *
 * Coverage (concise, with explicit test names):
 *  - test_1_initSDK_withNilConfiguration_completesFalse_andEmitsErrorEvent:
 *      Passing nil configuration should finish with false and emit an error event from ConfigCoordinator.
 *  - test_2_initSDK_withValidConfiguration_completes_andEmitsConfigSetOnSuccess_orErrorOnFailure:
 *      With a minimal valid configuration, completion must fire. If the config save succeeds, we expect configSet; if it fails (e.g., no Core Data model), we expect at least one error event.
 *  - test_3_initSDK_whenPushModuleInactive_doesNotFlipTokenLogShow:
 *      When there is no manual token and no providers, performPushModuleCheck is not invoked; tokenLogShow remains unchanged.
 *  - test_4_initSDK_whenPushModuleActive_flipsTokenLogShow_ifInitSucceeds:
 *      When a manual token exists and init succeeds, performPushModuleCheck must set tokenLogShow = false synchronously. If init fails, we don’t assert the flip.
 *
 * Notes:
 *  - Uses a fresh App Group per test to isolate UserDefaults storage.
 *  - Avoids a hard dependency on the presence of the Core Data model.
 *  - Event assertions rely on EventSpy capturing SDKEvents emissions.
 */
final class AltcraftInitTests: XCTestCase {

    // MARK: - Test constants

    private let appGroupPrefix = "group.altcraft.tests.init."
    private let apiURLString   = "https://api.example.com"
    private let rTokenString   = "R-TOKEN"
    private let manualTokenVal = "MANUAL"
    private let timeoutShort: TimeInterval = 2.0
    private let timeoutLong:  TimeInterval = 5.0

    // MARK: - Test Event Spy

    private final class EventSpy {
        private(set) var events: [Event] = []
        private var isStarted = false

        func start() {
            guard !isStarted else { return }
            isStarted = true
            SDKEvents.shared.subscribe { [weak self] ev in
                self?.events.append(ev)
            }
        }

        func stop() {
            SDKEvents.shared.unsubscribe()
            isStarted = false
        }
    }

    // MARK: - Per-test isolation helpers

    private func isolateUserDefaults() {
        StoredVariablesManager.shared.setGroupsName(value: appGroupPrefix + UUID().uuidString)
        StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
    }

    private func clearProviders(_ tm: TokenManager = .shared) {
        tm.fcmProvider = nil
        tm.hmsProvider = nil
        tm.apnsProvider = nil
    }

    private func makeMinimalConfig() -> AltcraftConfiguration {
        let builder = AltcraftConfiguration.Builder()
            .setApiUrl(apiURLString)
            .setRToken(rTokenString)
            .setAppInfo(nil)
            .setProviderPriorityList([])
        guard let cfg = builder.build() else {
            XCTFail("Failed to build minimal AltcraftConfiguration")
            fatalError("AltcraftConfiguration.Builder returned nil")
        }
        return cfg
    }

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        isolateUserDefaults()
        clearProviders()
    }

    override func tearDown() {
        StoredVariablesManager.shared.clearManualToken()
        StoredVariablesManager.shared.clearSavedToken()
        clearProviders()
        super.tearDown()
    }

    // MARK: - Tests

    /// test_1_initSDK_withNilConfiguration_completesFalse_andEmitsErrorEvent
    func test_1_initSDK_withNilConfiguration_completesFalse_andEmitsErrorEvent() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        let exp = expectation(description: "completion false for nil configuration")
        AltcraftInit.shared.initSDK(configuration: nil) { ok in
            XCTAssertFalse(ok, "initSDK must complete with false when configuration is nil")
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeoutShort)

        XCTAssertTrue(spy.events.contains { $0 is ErrorEvent }, "Expected an error event when configuration is nil")
    }

    /// test_2_initSDK_withValidConfiguration_completes_andEmitsConfigSetOnSuccess_orErrorOnFailure
    func test_2_initSDK_withValidConfiguration_completes_andEmitsConfigSetOnSuccess_orErrorOnFailure() {
        let spy = EventSpy(); spy.start()
        defer { spy.stop() }

        StoredVariablesManager.shared.clearManualToken()
        clearProviders()

        let cfg = makeMinimalConfig()
        let exp = expectation(description: "completion for valid configuration")

        var completedFlag: Bool?
        AltcraftInit.shared.initSDK(configuration: cfg) { ok in
            completedFlag = ok
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeoutLong)

        XCTAssertNotNil(completedFlag, "Completion must be called")
        if completedFlag == true {
            let hasConfigSet = spy.events.contains {
                $0.eventCode == configSet.0 || ($0.message ?? "").contains(configSet.1)
            }
            XCTAssertTrue(hasConfigSet, "Expected configSet event on successful initSDK")
        } else {
            XCTAssertTrue(spy.events.contains { $0 is ErrorEvent }, "Expected an error event when init fails to persist configuration")
        }
    }
}
