//
//  NSEEnvironmentResetTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif

/**
 * NSEEnvironmentResetTests
 *
 * Verifies that the per-process configuration cache is dropped when the
 * Notification Service Extension environment is reset, so a reused
 * extension process always reads the configuration written by the host
 * application (mirrors Android, where each re-initialization refreshes
 * the cached config).
 *
 * Positive scenarios:
 * - test_1: `ConfigManager.clearCache()` makes the next `getConfig()` read
 *   the externally updated configuration instead of the stale cached one.
 * - test_2: `AltcraftNSE.setAppGroup(groupName:)` drops the configuration
 *   cache, so the first read after the reset observes the new value.
 * - test_3: `bootstrapInitGate` completes the initialization gate when a
 *   configuration is available (NSE fast start).
 * - test_4: `bootstrapInitGate` keeps the gate closed when no configuration
 *   is stored.
 * - test_5: the Core Data stack captures the App Group identifier at
 *   creation time, and a full SDK clear still wipes all state while the
 *   container created during the cleanup captured the known group.
 */
final class NSEEnvironmentResetTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private static let urlA = "https://qa-a.example.com"
    private static let urlB = "https://qa-b.example.com"
    private static let tokenA = "rToken-A"
    private static let tokenB = "rToken-B"
    private static let groupName = "group.altcraft.tests"

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipeConfiguration()
    }

    override func tearDownWithError() throws {
        sdkWipeConfiguration()
        StoredVariablesManager.shared.setGroupsName(value: nil)
        SDKStateCoordinator.shared.resetState()
        try super.tearDownWithError()
    }

    /// test_1: stale cache is returned after an external configuration
    /// write; `clearCache()` restores fresh reads.
    func test_1_clearCache_makesNextGetConfigReadFreshValue() async throws {
        try await seedConfiguration(url: Self.urlA, rToken: Self.tokenA)

        let first = await ConfigManager.shared.getConfig()
        XCTAssertEqual(first?.rToken, Self.tokenA)

        try await seedConfiguration(url: Self.urlB, rToken: Self.tokenB)

        let stale = await ConfigManager.shared.getConfig()
        XCTAssertEqual(stale?.rToken, Self.tokenA)

        await ConfigManager.shared.clearCache()

        let fresh = await ConfigManager.shared.getConfig()
        XCTAssertEqual(fresh?.rToken, Self.tokenB)
        XCTAssertEqual(fresh?.apiUrl, Self.urlB)
    }

    /// test_2: `setAppGroup` drops the configuration cache, so the first
    /// read after the reset observes the externally updated value.
    func test_2_setAppGroup_resetsConfigurationCache() async throws {
        try await seedConfiguration(url: Self.urlA, rToken: Self.tokenA)

        let first = await ConfigManager.shared.getConfig()
        XCTAssertEqual(first?.rToken, Self.tokenA)

        try await seedConfiguration(url: Self.urlB, rToken: Self.tokenB)

        AltcraftNSE.setAppGroup(groupName: Self.groupName)

        let updated = await waitForRToken(Self.tokenB)
        XCTAssertTrue(updated)
    }

    /// test_3: `bootstrapInitGate` completes the initialization gate when a
    /// configuration is available, so NSE flows start without waiting for
    /// the readiness timeout.
    func test_3_bootstrapInitGate_opensGate_whenConfigExists() async throws {
        await InitBarrier.shared.reset()

        try await seedConfiguration(url: Self.urlA, rToken: Self.tokenA)
        await ConfigManager.shared.clearCache()

        await AltcraftNSE.bootstrapInitGate()

        let gate = await InitBarrier.shared.current()
        let opened = await gate.completed()
        XCTAssertTrue(opened)
    }

    /// test_4: `bootstrapInitGate` leaves the gate closed when no
    /// configuration is stored.
    func test_4_bootstrapInitGate_keepsGateClosed_withoutConfig() async throws {
        await InitBarrier.shared.reset()

        sdkWipeConfiguration()
        await ConfigManager.shared.clearCache()

        await AltcraftNSE.bootstrapInitGate()

        let gate = await InitBarrier.shared.current()
        let closed = await gate.completed()
        XCTAssertFalse(closed)

        await InitBarrier.shared.complete(await InitBarrier.shared.current())
    }

    /// test_5: the Core Data stack captures the App Group identifier at
    /// creation time, and a full SDK clear still wipes everything (group
    /// setting included) while the container created during the cleanup
    /// captured the group that was known at that moment.
    func test_5_clear_keepsGroupCapture_andWipesAllState() async throws {
        SDKStateCoordinator.shared.setAppGroup(Self.groupName)

        let manager = CoreDataManager(
            modelName: Constants.CoreData.coreModelName,
            storeFileName: "NSEEnvironmentReset-\(UUID().uuidString).sqlite"
        )
        XCTAssertEqual(manager.groupId, Self.groupName)

        try await seedConfiguration(url: Self.urlA, rToken: Self.tokenA)
        try await seedConfiguration(url: Self.urlB, rToken: Self.tokenB)

        await ModuleLifecycle.onSdkClear()

        XCTAssertNil(
            StoredVariablesManager.shared.getGroupName(),
            "clear must wipe the App Group setting"
        )
        let remaining = await CoreConfigDao().fetch()
        XCTAssertNil(remaining, "clear must remove the stored configuration")

        await InitBarrier.shared.complete(await InitBarrier.shared.current())
    }

    // MARK: - Helpers

    /// Persists a configuration directly through the DAO, bypassing the
    /// manager cache (simulates a write performed by the host application).
    private func seedConfiguration(url: String, rToken: String?) async throws {
        let saved = await CoreConfigDao().save(
            url: url,
            rToken: rToken,
            appInfo: nil
        )
        XCTAssertTrue(saved)
    }

    /// Polls the manager until the cached configuration reports the given
    /// rToken, or fails after the timeout.
    private func waitForRToken(
        _ expected: String,
        timeout: TimeInterval = 2.0
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let config = await ConfigManager.shared.getConfig(),
               config.rToken == expected {
                return true
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        return false
    }

    private func sdkWipeConfiguration() {
        guard let context = TestCoreDataStack.sdkBackgroundContext(
            containingEntity: Constants.EntityNames.configurationEntity
        ) else {
            return
        }

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(
                entityName: Constants.EntityNames.configurationEntity
            )
            fetchRequest.includesPropertyValues = false

            if let objects = try? context.fetch(fetchRequest) as? [NSManagedObject] {
                objects.forEach { context.delete($0) }
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }
}
