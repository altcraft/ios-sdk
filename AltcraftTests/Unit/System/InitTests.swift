//
//  AltcraftInitTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
@testable import Altcraft

/**
 * AltcraftInitTests
 *
 * Positive scenarios:
 *  - test_1: initSDK with nil configuration → completes false and emits error event.
 *  - test_2: initSDK with valid configuration → completes and emits configSet on success or error on failure.
 *  - test_3: initSDK when push module inactive → does not flip tokenLogShow.
 *  - test_4: initSDK when push module active → flips tokenLogShow if init succeeds.
 */
final class AltcraftInitTests: XCTestCase {

    private let appGroupPrefix = "group.altcraft.tests.init."
    private let apiURLString   = "https://api.example.com"
    private let rTokenString   = "R-TOKEN"
    private let manualTokenVal = "MANUAL"
    private let timeoutShort: TimeInterval = 2.0
    private let timeoutLong:  TimeInterval = 5.0

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

    /// test_1: initSDK with nil configuration completes false and emits error event
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

    /// test_2: initSDK with valid configuration completes and emits configSet on success or error on failure
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
