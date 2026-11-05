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
            Constants.EntityNames.configurationEntity
        ])
    }

    override func tearDownWithError() throws {
        wipeContext([
            InAppConstants.EntityNames.inAppsEntity,
            InAppConstants.EntityNames.inAppEntity,
            InAppConstants.EntityNames.personalPolicyEntity
        ], context: context)

        sdkWipe([
            Constants.EntityNames.configurationEntity
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
    /// suspended on the init barrier and reaches the readiness signal only
    /// once initialization is done (Android parity, `submitSdkCommand` with
    /// `initAwait = true`).
    ///
    /// `queue.submit` returns as soon as the job is enqueued, so completion
    /// is observed through the placements readiness waiter (`waitUntilReady`)
    /// released by the request body, not through the `requestPlacements`
    /// call itself.
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

        // Completing initialization releases the waiting request; the body
        // then finishes and signals readiness.
        await InitBarrier.shared.complete(gate)

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
            "request must resume after initialization completes"
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
