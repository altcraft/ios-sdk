//
//  RTokenChangeDispatchTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
@testable import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/**
 * RTokenChangeDispatchTests
 *
 * Initialization dispatch ordering guarantees for role-token changes
 * (`ModuleRegistry.notifyInitialized`):
 *
 * Positive scenarios:
 *  - test_1: A change missed at config time (JWT not yet available) is
 *    detected by the dispatch-time re-check and settles before the module
 *    initialization phase runs.
 *  - test_2: A change detected while the module initialization phase is
 *    running (JWT became available mid-dispatch) settles with the dispatch
 *    and the phase is re-run once.
 */
final class RTokenChangeDispatchTests: IsolatedTestCase {

    private let msgEqual = "Value must equal expected"

    override func tearDown() {
        JWTManager.shared.register(NullJWTProvider())
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
        super.tearDown()
    }

    /// Installs a JWT-mode configuration and the saved previous role token.
    private func setupJWTMode(savedToken: String) async -> Bool {
        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: nil
            )
            .build()
        )

        StoredVariablesManager.shared.setCurrentRToken(value: savedToken)

        return saved
    }

    /// test_1: dispatch-time re-check settles a missed change before module init
    ///
    /// The config-time check (`Init.initSDK` → `checkFromInit`) runs while
    /// the JWT is not yet available and misses the change. The dispatch-time
    /// re-check (`notifyInitialized` → `checkFromInit`) runs after the JWT
    /// became available: the change notification (module dispatch included)
    /// must complete before the module initialization phase starts.
    func test_1_dispatchReCheck_settlesChangeBeforeModuleInit() async {
        let provider = FirstReadNilJWTProvider()
        JWTManager.shared.register(provider)
        let saved = await setupJWTMode(savedToken: "r-old")
        XCTAssertTrue(saved)

        // Config-time check: the provider is not ready yet — change missed.
        await RTokenChange.shared.checkFromInit()

        // The JWT becomes available before the initialization dispatch.
        provider.arm(token: "r-new")

        let probe = DispatchProbeModule(moduleId: "probe-dispatch-1")
        await ModuleRegistry.shared.register(probe)
        defer { Task { await ModuleRegistry.shared.unregister(probe.moduleId) } }

        await ModuleRegistry.shared.notifyInitializedInternal()

        XCTAssertEqual(
            probe.events,
            ["rtoken", "init"],
            "the change must settle before the module initialization phase"
        )
        XCTAssertEqual(
            StoredVariablesManager.shared.getCurrentRToken(),
            "r-new",
            msgEqual
        )
    }

    /// test_2: change detected mid-dispatch settles and re-runs module init
    ///
    /// The JWT becomes available only while the module initialization phase
    /// is already running: the probe triggers the change inside
    /// `onSdkInitialized`. The notification must settle with the dispatch and
    /// the phase must be re-run exactly once against the new identity.
    func test_2_changeDuringDispatch_rerunsModuleInit() async {
        JWTManager.shared.register(NullJWTProvider())
        let saved = await setupJWTMode(savedToken: "r-old")
        XCTAssertTrue(saved)

        // Config-time and dispatch-time checks see no JWT — change missed.
        await RTokenChange.shared.checkFromInit()

        let provider = FirstReadNilJWTProvider()
        JWTManager.shared.register(provider)

        // The probe arms the provider and reads the JWT mid-dispatch, so the
        // change is detected while the module initialization phase runs.
        let probe = DispatchProbeModule(moduleId: "probe-dispatch-2") {
            provider.arm(token: "r-new")
            await RTokenChange.shared.checkFromJWT(
                jwt: makeRTokenJWTHelper("r-new")
            )
        }
        await ModuleRegistry.shared.register(probe)
        defer { Task { await ModuleRegistry.shared.unregister(probe.moduleId) } }

        await ModuleRegistry.shared.notifyInitializedInternal()

        XCTAssertEqual(
            probe.events,
            ["init", "rtoken", "init"],
            "the phase must re-run once after the mid-dispatch change settled"
        )
        XCTAssertEqual(probe.initCount, 2, msgEqual)
        XCTAssertEqual(
            StoredVariablesManager.shared.getCurrentRToken(),
            "r-new",
            msgEqual
        )
    }
}

/// JWT provider mirroring an app whose JWT is not yet available: reads before
/// `arm(token:)` return `nil`, reads after it return the issued JWT.
private final class FirstReadNilJWTProvider: JWTInterface {

    private let lock = NSLock()
    private var jwt: String?

    /// Issues the JWT from the next read on.
    func arm(token: String) {
        lock.lock()
        jwt = makeRTokenJWTHelper(token)
        lock.unlock()
    }

    func getToken() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return jwt
    }
}

/// JWT provider that supplies no token, used to reset the real `JWTManager`.
private final class NullJWTProvider: JWTInterface {

    func getToken() -> String? {
        nil
    }
}

/// Test module recording the lifecycle event order of the initialization
/// dispatch and the role-token change notification.
private final class DispatchProbeModule: AltcraftModule, @unchecked Sendable {

    let moduleId: String

    private let lock = NSLock()
    private var eventSequence: [String] = []
    private var initializedCounter = 0
    private var rtokenChangedFlag = false
    private let onInit: (@Sendable () async -> Void)?

    /// - Parameter onInit: Optional action performed inside
    ///   `onSdkInitialized` (used to trigger a mid-dispatch change).
    init(
        moduleId: String,
        onInit: (@Sendable () async -> Void)? = nil
    ) {
        self.moduleId = moduleId
        self.onInit = onInit
    }

    /// Recorded lifecycle events in dispatch order.
    var events: [String] {
        lock.lock()
        defer { lock.unlock() }
        return eventSequence
    }

    /// Number of `onSdkInitialized` invocations.
    var initCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return initializedCounter
    }

    /// Whether `onSdkRTokenChanged` has been dispatched.
    var rtokenChanged: Bool {
        lock.lock()
        defer { lock.unlock() }
        return rtokenChangedFlag
    }

    /// Records a lifecycle event in dispatch order.
    private func record(_ event: String) {
        lock.lock()
        eventSequence.append(event)
        lock.unlock()
    }

    /// Marks the rToken change notification as dispatched and records it.
    private func markRtokenChanged() {
        lock.lock()
        rtokenChangedFlag = true
        eventSequence.append("rtoken")
        lock.unlock()
    }

    func onSdkInitialized() async {
        lock.lock()
        initializedCounter += 1
        eventSequence.append("init")
        lock.unlock()

        await onInit?()
    }

    func onSdkClear() async {}

    func onSdkRTokenChanged() async {
        markRtokenChanged()
    }

    func processPending(enableRetry: Bool) async {}
}

/// Builds a minimal JWT carrying the given `rtoken` claim.
private func makeRTokenJWTHelper(_ token: String) -> String {
    let header = ["alg": "none", "typ": "JWT"]
    let payload = [Constants.AuthKeys.rtoken: token]

    func encode(_ object: [String: Any]) -> String? {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: []
            )
        else {
            return nil
        }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    guard let header64 = encode(header), let payload64 = encode(payload) else {
        return ""
    }

    return "\(header64).\(payload64)."
}
