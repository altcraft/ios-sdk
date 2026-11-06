//
//  InAppPlacementsTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
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
 * InAppPlacementsTests
 *
 * Positive scenarios:
 * - test_1: request with missing SDK configuration returns RetryEvent.
 * - test_2: processPlacements with missing SDK configuration returns false.
 *
 * Edge scenarios:
 * - test_3: processPlacements does not create in-app state when request cannot be built.
 * - test_4: request event is retry when backend request data cannot be created.
 * - test_6: processPlacements error path releases parked placements waiters.
 * - test_8: reset keeps parked waiters parked until the next gate completion.
 * - test_9: trigger identity guard blocks processing with stale identity.
 * - test_10: requestPlacements with unavailable authentication keeps the gate closed.
 * - test_11: auto request disabled releases cached placements only for the current identity.
 * - test_12: awaited requestPlacements completes the processing before returning.
 *
 */
final class InAppPlacementsTests: IsolatedTestCase {

    private var context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

    override func setUpWithError() throws {
        try super.setUpWithError()

        context = inAppDatabase.getContext()

        wipeContext([
            InAppConstants.EntityNames.inAppsEntity,
            InAppConstants.EntityNames.inAppEntity,
            InAppConstants.EntityNames.personalPolicyEntity
        ], context: context)

        sdkWipe([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.authenticationEntity
        ])
    }

    override func tearDownWithError() throws {
        wipeContext([
            InAppConstants.EntityNames.inAppsEntity,
            InAppConstants.EntityNames.inAppEntity,
            InAppConstants.EntityNames.personalPolicyEntity
        ], context: context)

        sdkWipe([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.authenticationEntity
        ])

        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)

        try super.tearDownWithError()
    }

    private func fetchInAppsState() throws -> InAppsEntity? {
        var object: InAppsEntity?

        context.performAndWait {
            let req = NSFetchRequest<InAppsEntity>(
                entityName: InAppConstants.EntityNames.inAppsEntity
            )
            req.fetchLimit = 1

            object = try? context.fetch(req).first
        }

        return object
    }

    private func makeState(
        acid: String = "acid-1",
        deviceId: String = "device-1",
        lastRequestTime: Int64 = 0,
        lastPublish: Int64 = 0,
        placementRulesChecksum: String = ""
    ) -> InAppModel.InAppsState {
        InAppModel.InAppsState(
            acid: acid,
            deviceId: deviceId,
            lastRequestTime: lastRequestTime,
            lastPublish: lastPublish,
            placementRulesChecksum: placementRulesChecksum
        )
    }

    private func wipeContext(
        _ entities: [String],
        context: NSManagedObjectContext
    ) {
        context.performAndWait {
            for name in entities {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: name
                )

                if let objects = try? context.fetch(req) as? [NSManagedObject] {
                    objects.forEach {
                        context.delete($0)
                    }
                }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    private func sdkWipe(_ entityNames: [String]) {
        for name in entityNames {
            guard let ctx = TestCoreDataStack.sdkBackgroundContext(containingEntity: name) else {
                continue
            }
            let sema = DispatchSemaphore(value: 0)

            ctx.perform {
                let req = NSFetchRequest<NSFetchRequestResult>(
                    entityName: name
                )
                req.includesPropertyValues = false

                if let objects = try? ctx.fetch(req) as? [NSManagedObject] {
                    objects.forEach {
                        ctx.delete($0)
                    }
                }

                if ctx.hasChanges {
                    try? ctx.save()
                }

                sema.signal()
            }

            _ = sema.wait(timeout: .now() + 5.0)
        }
    }

    /// test_1: request with missing SDK configuration returns RetryEvent
    func test_1_request_with_missing_sdk_configuration_returns_retry_event() async {
        let event = await InAppPlacementsProcess.shared.test_inApp_placements_requestEvent(
            state: makeState()
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_2: processPlacements with missing SDK configuration returns false
    func test_2_processPlacements_with_missing_sdk_configuration_returns_false() async {
        let result = await InAppPlacementsProcess.shared.test_inApp_placements_processPlacements()

        XCTAssertFalse(result)
    }

    /// test_3: processPlacements does not create in-app state when request cannot be built
    func test_3_processPlacements_does_not_create_inapp_state_when_request_cannot_be_built() async throws {
        let result = await InAppPlacementsProcess.shared.test_inApp_placements_processPlacements()

        XCTAssertFalse(result)
        XCTAssertNil(try fetchInAppsState())
    }

    /// test_4: request event is retry when backend request data cannot be created
    func test_4_request_event_is_retry_when_backend_request_data_cannot_be_created() async {
        let event = await InAppPlacementsProcess.shared.test_inApp_placements_requestEvent(
            state: makeState(
                acid: "",
                deviceId: "",
                lastRequestTime: 0,
                lastPublish: 0,
                placementRulesChecksum: ""
            )
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_5: request event is retry when backend request data cannot be created
    func test_5_request_event_is_retry_when_backend_request_data_cannot_be_created() async {
        let event = await InAppPlacementsProcess.shared.test_inApp_placements_requestEvent(
            state: makeState(
                acid: "",
                deviceId: "",
                lastRequestTime: 0,
                lastPublish: 0,
                placementRulesChecksum: ""
            )
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_6: processPlacements error path releases parked placements waiters
    func test_6_processPlacements_error_path_releases_waiters() async {
        // Clear readiness so the waiter actually parks.
        await InAppPlacementsProcess.shared.reset()

        let box = WaiterFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            box.set()
        }

        // Give the waiter time to park before processing runs.
        try? await Task.sleep(nanoseconds: 200_000_000)

        _ = await InAppPlacementsProcess.shared
            .test_inApp_placements_processPlacements()

        // The parked waiter must be released by the readiness signal.
        var released = false
        for _ in 0..<50 {
            if box.isSet {
                released = true
                break
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertTrue(released)
        waiter.cancel()
    }

    // MARK: - Init waiting

    /// Resets the shared init barrier to a fresh (incomplete) gate.
    private func resetBarrierToFreshGate() async -> InitGate {
        let current = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(current)
        try? await Task.sleep(nanoseconds: 10_000_000)

        var gate = await InitBarrier.shared.reserve()
        var attempts = 0

        while await gate.completed(), attempts < 5 {
            await InitBarrier.shared.complete(gate)
            try? await Task.sleep(nanoseconds: 10_000_000)
            gate = await InitBarrier.shared.reserve()
            attempts += 1
        }

        return gate
    }

    /// Thread-safe flag set when the placements request task completes.
    private final class CompletionFlag: @unchecked Sendable {

        private let lock = NSLock()
        private var value = false

        /// Whether the flag has been set.
        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        /// Sets the flag.
        func set() {
            lock.lock()
            value = true
            lock.unlock()
        }
    }
    /// test_7: requestPlacements waits for SDK initialization before processing
    ///
    /// A placements request submitted before `initialization` completes must
    /// not run against a missing configuration: the request task stays
    /// suspended on the init barrier and only reaches the placements flow
    /// once initialization is done (Android parity, `submitSdkCommand` with
    /// `initAwait = true`).
    ///
    /// `queue.submit` returns as soon as the job is enqueued, so completion
    /// is observed through the placements readiness waiter (`waitUntilReady`).
    /// After initialization the planning flow cannot build placements without
    /// configuration/authentication data, so the gate stays closed and the
    /// parked waiter is released only by the budget-exhaustion safety.
    func test_7_requestPlacements_waitsForInit_thenResumes() async throws {
        // Fresh closed gate: initialization is not complete.
        let gate = await resetBarrierToFreshGate()

        // Clear readiness so the waiter below actually parks.
        await InAppPlacementsProcess.shared.reset()

        let done = CompletionFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            done.set()
        }

        let task = Task {
            await InAppPlacementsProcess.shared.requestPlacements(
                userReq: true,
                enableRetry: false
            )
        }

        // While initialization is incomplete the request must not reach the
        // readiness signal.
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(
            done.isSet,
            "request must wait for initialization to complete"
        )

        // Completing initialization lets the request body run; without
        // configuration/authentication data the planning flow cannot open
        // the gate, so the waiter keeps waiting.
        await InitBarrier.shared.complete(gate)

        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(
            done.isSet,
            "planning error must keep the gate closed"
        )

        // The budget-exhaustion safety releases the parked waiter.
        await InAppPlacementsProcess.shared.retryBudgetExhausted()

        var finished = false
        for _ in 0..<80 {
            if done.isSet {
                finished = true
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertTrue(
            finished,
            "waiter must be released when the gate completes"
        )

        waiter.cancel()
        task.cancel()
    }

    /// test_8: reset keeps parked waiters parked until the next gate completion
    ///
    /// Android parity (`LIFOQueue` re-park loop): re-arming the placements
    /// gate must not release a parked trigger worker — it stays parked and is
    /// resumed only when the next placements pass completes the re-armed
    /// gate, so queued triggers are processed with fresh placement data.
    func test_8_reset_keepsParkedWaitersParked_untilNextGateCompletion() async {
        // Re-arm the gate so the waiter below actually parks.
        await InAppPlacementsProcess.shared.reset()

        let box = WaiterFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            box.set()
        }

        // Give the waiter time to park.
        try? await Task.sleep(nanoseconds: 200_000_000)

        // The reset itself must not release the parked waiter.
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(
            box.isSet,
            "reset() must keep parked waiters parked"
        )

        // The next gate completion releases the waiter.
        await InAppPlacementsProcess.shared.retryBudgetExhausted()

        var released = false
        for _ in 0..<50 {
            if box.isSet {
                released = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertTrue(
            released,
            "waiter must be released when the re-armed gate completes"
        )

        waiter.cancel()
    }

    /// test_9: trigger identity guard blocks processing with stale identity
    ///
    /// Early placements-gate completions (request error, "too early", auto
    /// request disabled) release the trigger worker without fresh data. The
    /// worker must verify that the stored placements identity still matches
    /// the current one before presenting campaigns from the database —
    /// otherwise a campaign of the previous resource is displayed between
    /// the gate release and the rToken-change wipe.
    func test_9_triggerIdentityGuard_blocksStaleIdentity() async throws {
        // Ensure the environment resolves authentication data.
        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "guard-rt"
            )
            .build()
        )
        XCTAssertTrue(saved, "configuration must be installed")

        // Seed the authentication entity so internal auth data resolves.
        await Authenticate.shared.setAuth()

        let auth = try await InAppEnvironment.fresh().internalAuth()

        // Identity bound to a previous resource/session.
        _ = await InAppsDAO.setInAppsEntity(
            acid: "stale-acid",
            lastRequestTime: 0,
            deviceId: "stale-device",
            lastPublish: 0,
            placementRulesChecksum: ""
        )

        let stale = await InAppProcTrigger.isTriggerIdentityCurrent()
        XCTAssertFalse(
            stale,
            "stale placements identity must not pass the trigger guard"
        )

        // Identity matching the current authentication data passes.
        _ = await InAppsDAO.setInAppsEntity(
            acid: auth.currentAcid,
            lastRequestTime: 0,
            deviceId: auth.deviceId,
            lastPublish: 0,
            placementRulesChecksum: ""
        )

        let current = await InAppProcTrigger.isTriggerIdentityCurrent()
        XCTAssertTrue(
            current,
            "current placements identity must pass the trigger guard"
        )

        await InAppsDAO.clearInAppsData()
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }

    /// test_10: requestPlacements with unavailable authentication keeps the gate closed
    ///
    /// A planning error (for example, missing internal authentication data)
    /// must not release the trigger worker: without validated identity the
    /// stored campaigns cannot be shown. A later request releases the parked
    /// worker with fresh, identity-checked data.
    func test_10_requestPlacements_authUnavailable_keepsGateClosed() async {
        // Ensure SDK initialization is ready so the request body runs
        // immediately instead of waiting out the init barrier timeout.
        let currentGate = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(currentGate)

        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "gate-rt"
            )
            .build()
        )
        XCTAssertTrue(saved, "configuration must be installed")

        // No authentication entity seeded: internal auth data is unavailable.
        await InAppPlacementsProcess.shared.reset()

        let box = WaiterFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            box.set()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        await InAppPlacementsProcess.shared.requestPlacements()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(
            box.isSet,
            "gate must stay closed when authentication data is unavailable"
        )

        waiter.cancel()
        await InAppConfigManager.shared.clearCache()
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }

    /// test_11: auto request disabled releases cached placements only for the current identity
    ///
    /// With automatic requests disabled no fresh request validates the data,
    /// so the cached placements may only be released when their stored
    /// identity matches the current one. A stale identity keeps the gate
    /// closed until a user-initiated request loads fresh data.
    func test_11_autoRequestDisabled_releasesCachedPlacementsOnlyForCurrentIdentity() async throws {
        // Ensure SDK initialization is ready so placements requests are not
        // suspended on the init barrier (otherwise the default gate would
        // delay each request by its timeout).
        let currentGate = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(currentGate)

        // Apply the in-app module configuration with automatic requests
        // disabled (the module configuration is independent of the core one).
        await InAppConfigManager.shared.setConfig(
            InAppConfiguration(
                inAppAutoRequest: false,
                placementsRequestInterval: 600_000,
                maxPlacements: 10
            )
        )

        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "gate-rt"
            )
            .build()
        )
        XCTAssertTrue(saved, "configuration must be installed")

        // Seed the authentication entity so internal auth data resolves.
        await Authenticate.shared.setAuth()

        // Identity bound to a previous resource/session.
        _ = await InAppsDAO.setInAppsEntity(
            acid: "stale-acid",
            lastRequestTime: 0,
            deviceId: "stale-device",
            lastPublish: 0,
            placementRulesChecksum: ""
        )

        await InAppPlacementsProcess.shared.reset()

        let box = WaiterFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            box.set()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        await InAppPlacementsProcess.shared.requestPlacements()

        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertFalse(
            box.isSet,
            "stale cached placements must not be released when auto request is disabled"
        )

        // Identity matching the current authentication data passes.
        let auth = try await InAppEnvironment.fresh().internalAuth()
        _ = await InAppsDAO.setInAppsEntity(
            acid: auth.currentAcid,
            lastRequestTime: 0,
            deviceId: auth.deviceId,
            lastPublish: 0,
            placementRulesChecksum: ""
        )

        await InAppPlacementsProcess.shared.requestPlacements()

        var released = false
        for _ in 0..<50 {
            if box.isSet {
                released = true
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        XCTAssertTrue(
            released,
            "current cached placements must be released when auto request is disabled"
        )

        waiter.cancel()
        await InAppsDAO.clearInAppsData()
        await InAppConfigManager.shared.clearCache()
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }

    /// test_12: awaited requestPlacements completes the processing before returning
    ///
    /// The background refresh path awaits the placements processing: when the
    /// awaited call returns, the queue job must already have completed its
    /// body. Online the pipeline runs inline within the queue job (the normal
    /// two-stage submit is flattened); offline the attempt is not consumed
    /// and the call falls back to the fire-and-forget enqueue.
    func test_12_requestPlacementsAwaited_releasesGateBeforeReturn() async throws {
        // Ensure SDK initialization is ready so the request body runs
        // immediately instead of waiting out the init barrier timeout.
        let currentGate = await InitBarrier.shared.current()
        await InitBarrier.shared.complete(currentGate)

        await InAppConfigManager.shared.setConfig(
            InAppConfiguration(
                inAppAutoRequest: false,
                placementsRequestInterval: 600_000,
                maxPlacements: 10
            )
        )

        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "gate-rt"
            )
            .build()
        )
        XCTAssertTrue(saved, "configuration must be installed")

        // Seed the authentication entity and cached placements bound to the
        // current identity: the auto-request-disabled path releases the gate
        // for the matching identity without any network involvement.
        await Authenticate.shared.setAuth()

        let auth = try await InAppEnvironment.fresh().internalAuth()
        _ = await InAppsDAO.setInAppsEntity(
            acid: auth.currentAcid,
            lastRequestTime: 0,
            deviceId: auth.deviceId,
            lastPublish: 0,
            placementRulesChecksum: ""
        )

        await InAppPlacementsProcess.shared.reset()

        let box = WaiterFlag()
        let waiter = Task {
            await InAppPlacementsProcess.shared.waitUntilReady()
            box.set()
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        let online = await NetworkMonitor.shared.isOnline()

        await InAppPlacementsProcess.shared.requestPlacements(
            awaitCompletion: true
        )

        if online {
            XCTAssertTrue(
                box.isSet,
                "awaited request must release the placements gate before returning"
            )
        } else {
            // Offline fallback: the request stays fire-and-forget; the gate
            // is released asynchronously by the enqueued job.
            var released = false
            for _ in 0..<50 {
                if box.isSet {
                    released = true
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            XCTAssertTrue(
                released,
                "offline fallback must still release the gate asynchronously"
            )
        }

        waiter.cancel()
        await InAppsDAO.clearInAppsData()
        await InAppConfigManager.shared.clearCache()
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }
}

/// Thread-safe flag used to detect waiter task completion in tests.
private final class WaiterFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var value = false

    /// Whether the flag has been set.
    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    /// Sets the flag.
    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
