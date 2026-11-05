//
//  ProfileUpdateTests.swift
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
 * ProfileUpdateTests
 *
 * Positive scenarios:
 * - test_1: profileUpdateRequest builds valid POST JSON request with Authorization header.
 * - test_2: request with invalid objectID returns RetryEvent when request data cannot be built.
 * - test_3: request with non-buildable payload returns RetryEvent when request cannot be created.
 * - test_4: processUpdate on RetryEvent path increments retryCount and returns true.
 * - test_5: processUpdate on max retry deletes entity and returns false.
 * - test_6: processUpdates stops on the first retrying entity and leaves the next one untouched.
 * - test_7: processUpdates with empty queue returns true.
 * - test_8: retryLimit with invalid objectID returns true when objectID is invalid.
 * - test_9: retryLimit increments retryCount until max, then deletes entity.
 *
 */
final class ProfileUpdateTests: IsolatedTestCase {

    private var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        context = profileDatabase.getContext()
        try wipeUpdates()
    }

    override func tearDownWithError() throws {
        try wipeUpdates()
        context = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeUpdate(
        userTag: String = "user-1",
        time: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        profileFields: [String: Any?]? = ["age": 30, "name": "Ann"],
        skipTriggers: Bool = false,
        retryCount: Int16 = 0,
        maxRetryCount: Int16 = 2
    ) throws -> NSManagedObjectID {
        var objectID: NSManagedObjectID?

        context.performAndWait {
            let entity = NSEntityDescription.insertNewObject(
                forEntityName: ProfileConstants.EntityNames.profileUpdateEntity,
                into: context
            )

            entity.setValue(userTag, forKey: "userTag")
            entity.setValue(UUID().uuidString, forKey: "requestId")
            entity.setValue(time, forKey: "time")
            entity.setValue(encodeAnyMap(profileFields), forKey: "profileFields")
            entity.setValue(skipTriggers, forKey: "skipTriggers")
            entity.setValue(retryCount, forKey: "retryCount")
            entity.setValue(maxRetryCount, forKey: "maxRetryCount")

            do {
                if entity.objectID.isTemporaryID {
                    try context.obtainPermanentIDs(for: [entity])
                }
                try context.save()
                objectID = entity.objectID
            } catch {
                XCTFail("Failed to save ProfileUpdateEntity: \(error)")
            }
        }

        return try XCTUnwrap(objectID)
    }

    private func deleteUpdate(by id: NSManagedObjectID) throws {
        context.performAndWait {
            guard let object = resolveObject(in: context, from: id) else {
                return
            }

            context.delete(object)

            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                XCTFail("Failed to delete ProfileUpdateEntity: \(error)")
            }
        }
    }

    private func fetchUpdate(by id: NSManagedObjectID) throws -> ProfileUpdateEntity? {
        var object: ProfileUpdateEntity?

        context.performAndWait {
            object = resolveObject(in: context, from: id) as? ProfileUpdateEntity
        }

        return object
    }

    private func fetchAllUpdates() throws -> [ProfileUpdateEntity] {
        var objects: [ProfileUpdateEntity] = []

        context.performAndWait {
            let req = NSFetchRequest<ProfileUpdateEntity>(entityName: ProfileConstants.EntityNames.profileUpdateEntity)
            objects = (try? context.fetch(req)) ?? []
        }

        return objects
    }

    private func wipeUpdates() throws {
        context.performAndWait {
            let req = NSFetchRequest<NSFetchRequestResult>(entityName: ProfileConstants.EntityNames.profileUpdateEntity)

            if let objects = try? context.fetch(req) as? [NSManagedObject] {
                objects.forEach { context.delete($0) }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    /// test_2: request with invalid objectID returns RetryEvent when request data cannot be built
    func test_2_request_with_invalid_objectID_returns_retry_event_when_request_data_cannot_be_built() async throws {
        let id = try makeUpdate()
        try deleteUpdate(by: id)

        let event = await ProfileUpdateProcess.shared.test_profile_update_request(
            context: context,
            update: id
        )

        XCTAssertTrue(event is RetryEvent)
    }

    /// test_5: processUpdate on max retry deletes entity and returns false
    func test_5_processUpdate_on_max_retry_deletes_entity_and_returns_false() async throws {
        let id = try makeUpdate(
            profileFields: ["bad": Date()],
            retryCount: 0,
            maxRetryCount: 0
        )

        let shouldStopAndRetryLater = await ProfileUpdateProcess.shared.test_profile_update_processUpdate(
            context: context,
            update: id
        )

        XCTAssertFalse(shouldStopAndRetryLater)
        XCTAssertNil(try fetchUpdate(by: id))
    }

    /// test_7: processUpdates with empty queue returns true
    func test_7_processUpdates_with_empty_queue_returns_true() async throws {
        let result = try await ProfileUpdateProcess.shared.test_profile_update_processUpdates(
            userTag: "missing-\(UUID().uuidString)"
        )

        XCTAssertTrue(result)
    }

    /// test_8: retryLimit with invalid objectID returns true when objectID is invalid
    func test_8_retryLimit_with_invalid_objectID_returns_true_when_objectID_is_invalid() async throws {
        let id = try makeUpdate()
        try deleteUpdate(by: id)

        let deleted = await retryLimit(
            context: context,
            objectID: id
        )

        XCTAssertTrue(deleted)
    }

    /// test_9: retryLimit increments retryCount until max, then deletes entity
    func test_9_retryLimit_increments_retryCount_until_max_then_deletes_entity() async throws {
        let id = try makeUpdate(maxRetryCount: 2)

        let deleted1 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted1)

        let first = try XCTUnwrap(fetchUpdate(by: id))
        XCTAssertEqual(first.retryCount, 1)

        let deleted2 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertFalse(deleted2)

        let second = try XCTUnwrap(fetchUpdate(by: id))
        XCTAssertEqual(second.retryCount, 2)

        let deleted3 = await retryLimit(
            context: context,
            objectID: id
        )
        XCTAssertTrue(deleted3)

        let all = try fetchAllUpdates()
        XCTAssertTrue(all.isEmpty)
    }
}

// Lifecycle regression coverage uses the real runtime registration path.
extension ProfileUpdateTests {
    func test_linked_modules_register_without_facade_access() async {
        await ModuleRegistry.shared.unregister(ProfileConstants.Module.id)
        await ModuleRegistry.shared.unregister(TargetConstants.Module.id)
        await ModuleRegistry.shared.registerLinkedModules()
        let ids = await ModuleRegistry.shared.allModules().map(\.moduleId)
        XCTAssertTrue(ids.contains(ProfileConstants.Module.id))
        XCTAssertTrue(ids.contains(TargetConstants.Module.id))
    }

    func test_clear_removes_profile_and_target_pending_data() async throws {
        _ = try makeUpdate()
        let targetContext = targetDatabase.getContext()
        try await targetContext.performAsync {
            let entity = TargetEntity(context: targetContext)
            entity.userTag = "old-user"
            entity.requestId = UUID().uuidString
            try targetContext.save()
        }
        await ModuleRegistry.shared.unregister(ProfileConstants.Module.id)
        await ModuleRegistry.shared.unregister(TargetConstants.Module.id)
        await withCheckedContinuation { continuation in
            AltcraftSDK.clear { continuation.resume() }
        }
        let profiles = try await profileDatabase.performBackgroundTask { context in
            try context.count(for: ProfileUpdateEntity.fetchRequest())
        }
        let targets = try await targetDatabase.performBackgroundTask { context in
            try context.count(for: TargetEntity.fetchRequest())
        }
        XCTAssertEqual(profiles, 0)
        XCTAssertEqual(targets, 0)
    }

    func test_rtoken_change_clears_pending_profile_data() async throws {
        // Start from a clean persisted token so the first save is the
        // "first saved token" case (no notification).
        StoredVariablesManager.shared.setCurrentRToken(value: nil)

        let initialSaved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "old"
            )
            .build()
        )
        XCTAssertTrue(initialSaved)

        // Persist the first token (Android parity: the comparison runs
        // after the configuration is installed).
        await RTokenChange.shared.checkFromConfig()

        _ = try makeUpdate()
        let targetContext = targetDatabase.getContext()
        try await targetContext.performAsync {
            let entity = TargetEntity(context: targetContext)
            entity.userTag = "old-user"
            entity.requestId = UUID().uuidString
            try targetContext.save()
        }
        await ModuleRegistry.shared.unregister(ProfileConstants.Module.id)
        await ModuleRegistry.shared.unregister(TargetConstants.Module.id)
        let saved = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://example.invalid",
                rToken: "new"
            )
            .build()
        )
        XCTAssertTrue(saved)

        // A previously saved token that differs from the new one notifies
        // the modules (Android parity, `RTokenChange`).
        await RTokenChange.shared.checkFromConfig()

        let targets = try await targetDatabase.performBackgroundTask { context in
            try context.count(for: TargetEntity.fetchRequest())
        }
        XCTAssertEqual(targets, 0)
        let count = try await profileDatabase.performBackgroundTask { context in
            try context.count(for: ProfileUpdateEntity.fetchRequest())
        }
        XCTAssertEqual(count, 0)

        StoredVariablesManager.shared.setCurrentRToken(value: nil)
    }

    func test_queue_reset_invalidates_running_request_context() async {
        let queue = SerialCommandQueue(label: "test.lifecycle.epoch", usesEpoch: true)
        let entered = expectation(description: "entered")
        let finished = expectation(description: "finished")
        let gate = LifecycleTestGate()
        queue.submit {
            entered.fulfill()
            await gate.wait()
            XCTAssertFalse(SerialCommandQueue.isCurrent())
            XCTAssertFalse(SerialCommandQueue.performIfCurrent {
                XCTFail("An invalidated queue must not start a request")
            })
            finished.fulfill()
        }
        await fulfillment(of: [entered], timeout: 2)
        queue.reset()
        await gate.open()
        await fulfillment(of: [finished], timeout: 2)
    }

    // MARK: - Init waiting

    /// Stores the SDK configuration directly (bypasses `CoreConfigDao.save`
    /// so no rToken-change notifications reach registered modules).
    private func storeConfig(apiUrl: String, rToken: String) {
        let sdkContext = CoreDataManager.shared.getContext()

        sdkContext.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(
                entityName: Constants.EntityNames.configurationEntity
            )
            request.includesPropertyValues = false

            if let stale = try? sdkContext.fetch(request) as? [NSManagedObject] {
                stale.forEach { sdkContext.delete($0) }
            }

            let entity = NSEntityDescription.insertNewObject(
                forEntityName: Constants.EntityNames.configurationEntity,
                into: sdkContext
            )
            entity.setValue(apiUrl, forKey: "url")
            entity.setValue(rToken, forKey: "rToken")

            try? sdkContext.save()
        }
    }

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

    /// test_10: updateProfileFields waits for SDK initialization before processing
    ///
    /// An update submitted before `initialization` completes must not be
    /// dropped: the process waits on the init barrier and stores the update
    /// once the configuration is installed (Android parity,
    /// `submitSdkCommand` with `initAwait = true`).
    func test_10_updateProfileFields_waitsForInit_thenProcesses() async throws {
        // Configuration is present, but initialization has not completed.
        storeConfig(apiUrl: "://invalid", rToken: "rt-init-test")
        await ConfigManager.shared.clearCache()

        let gate = await resetBarrierToFreshGate()

        let baseline = try await profileDatabase.performBackgroundTask { context in
            try context.count(for: ProfileUpdateEntity.fetchRequest())
        }
        XCTAssertEqual(baseline, 0)

        async let run: Void = ProfileUpdateProcess.shared.updateProfileFields(
            profileFields: encodeAnyMap(["age": 30])
        )

        // While initialization is incomplete the update must not be processed.
        try? await Task.sleep(nanoseconds: 200_000_000)
        let during = try await profileDatabase.performBackgroundTask { context in
            try context.count(for: ProfileUpdateEntity.fetchRequest())
        }
        XCTAssertEqual(during, baseline)

        // Completing initialization releases the waiting update.
        await InitBarrier.shared.complete(gate)
        _ = await run

        // The submitted job returns as soon as it is enqueued, so poll for
        // the stored update instead of asserting immediately.
        var processed = baseline
        for _ in 0..<60 {
            processed = try await profileDatabase.performBackgroundTask { context in
                try context.count(for: ProfileUpdateEntity.fetchRequest())
            }
            if processed == baseline + 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(
            processed,
            baseline + 1,
            "update must be stored after initialization completes"
        )
    }
}

private actor LifecycleTestGate {
    private var opened = false
    private var continuation: CheckedContinuation<Void, Never>?
    func wait() async {
        if opened { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func open() {
        opened = true
        continuation?.resume()
        continuation = nil
    }
}
