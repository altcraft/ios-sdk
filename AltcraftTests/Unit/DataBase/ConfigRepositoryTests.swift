//
//  ConfigRepositoryTests.swift
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
* ConfigRepositoryTests
*
 * Positive scenarios:
 * - test_1: setConfig creates new and persists all fields.
 * - test_2: setConfig updates existing configuration without duplicates.
 * - test_3: rToken change check (RTokenChange.checkFromConfig) triggers the
 *   subscription purge; the first saved token does not.
 * - test_4: getConfig returns nil when URL is empty.
 * - test_5: doesConfigurationEntityExist returns false then true.
 * - test_7: setConfig token → nil does not trigger the purge.
 * - test_8: setConfig nil → token does not trigger the purge.
 *
 * Negative scenarios:
 * - test_6: setConfig with an invalid configuration deletes the stored
 *   entity and returns false.
 */
final class ConfigRepositoryTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private var sdkContainer: NSPersistentContainer {
        CoreDataManager.shared.persistentContainer
    }

    private var sdkViewContext: NSManagedObjectContext {
        sdkContainer.viewContext
    }

    private func sdkNewBackgroundContext() -> NSManagedObjectContext {
        let context = sdkContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        return context
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
        sdkWipe([
            Constants.EntityNames.configurationEntity,
            PushConstants.EntityNames.subscribeEntity,
            TargetConstants.EntityNames.targetEventEntity,
            ProfileConstants.EntityNames.profileUpdateEntity
        ])
    }

    override func tearDownWithError() throws {
        sdkWipe([
            Constants.EntityNames.configurationEntity,
            PushConstants.EntityNames.subscribeEntity,
            TargetConstants.EntityNames.targetEventEntity,
            ProfileConstants.EntityNames.profileUpdateEntity
        ])
        StoredVariablesManager.shared.setCurrentRToken(value: nil)
        StoredVariablesManager.shared.setCritDB(value: false)
        try super.tearDownWithError()
    }

    private func sdkCount(entityName: String) -> Int? {
        guard let context = TestCoreDataStack.sdkBackgroundContext(containingEntity: entityName) else {
            return nil
        }

        var result: Int?

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.includesSubentities = true

            do {
                result = try context.count(for: fetchRequest)
            } catch {
                result = nil
            }
        }

        return result
    }

    private func sdkWipe(_ entityNames: [String]) {
        for entityName in entityNames {
            guard let context = TestCoreDataStack.sdkBackgroundContext(containingEntity: entityName) else {
                continue
            }

            context.performAndWait {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
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

    private func sdkFetchSingleConfigurationEntity() -> ConfigurationEntity? {
        let context = sdkViewContext
        var entity: ConfigurationEntity?

        context.performAndWait {
            let fetchRequest: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            fetchRequest.fetchLimit = 1
            entity = try? context.fetch(fetchRequest).first
        }

        return entity
    }

    private func decodeAppInfoData(_ data: Data?) -> AppInfo? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(AppInfo.self, from: data)
    }

    private func sdkSeedSubscribe(count: Int) throws {
        guard let context = TestCoreDataStack.sdkBackgroundContext(
            containingEntity: PushConstants.EntityNames.subscribeEntity
        ) else {
            throw NSError(
                domain: "ConfigRepositoryTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Entity PushSubscribeEntity not found"]
            )
        }
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: PushConstants.EntityNames.subscribeEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigRepositoryTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity PushSubscribeEntity not found"]
                )
                return
            }

            for _ in 0..<count {
                _ = NSEntityDescription.insertNewObject(
                    forEntityName: PushConstants.EntityNames.subscribeEntity,
                    into: context
                )
            }

            do {
                try context.save()
            } catch {
                thrownError = error
            }
        }

        if let thrownError {
            throw thrownError
        }
    }

    private func sdkSeedTargetEvents(count: Int) throws {
        guard let context = TestCoreDataStack.sdkBackgroundContext(
            containingEntity: TargetConstants.EntityNames.targetEventEntity
        ) else {
            throw NSError(
                domain: "ConfigRepositoryTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Entity TargetEntity not found"]
            )
        }
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: TargetConstants.EntityNames.targetEventEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigRepositoryTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity TargetEntity not found"]
                )
                return
            }

            for index in 0..<count {
                let entity = TargetEntity(context: context)
                entity.userTag = "u"
                entity.sid = "sid-\(index)"
                entity.eventName = "open"
                entity.time = Int64(1_700_000_000_000 + index)
                entity.timeZone = 180
                entity.retryCount = 0
                entity.maxRetryCount = 3
            }

            do {
                try context.save()
            } catch {
                thrownError = error
            }
        }

        if let thrownError {
            throw thrownError
        }
    }

    private func sdkSeedProfileUpdates(count: Int) throws {
        guard let context = TestCoreDataStack.sdkBackgroundContext(
            containingEntity: ProfileConstants.EntityNames.profileUpdateEntity
        ) else {
            throw NSError(
                domain: "ConfigRepositoryTests",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Entity ProfileUpdateEntity not found"]
            )
        }
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: ProfileConstants.EntityNames.profileUpdateEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigRepositoryTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity ProfileUpdateEntity not found"]
                )
                return
            }

            for index in 0..<count {
                let entity = ProfileUpdateEntity(context: context)
                entity.time = Int64(1_700_000_000_000 + index)
                entity.retryCount = 0
                entity.maxRetryCount = 3
            }

            do {
                try context.save()
            } catch {
                thrownError = error
            }
        }

        if let thrownError {
            throw thrownError
        }
    }

    /// test_1: setConfig creates new and persists all fields
    func test_1_set_config_creates_new_and_persists_all_fields() async {
        let url = "https://api.altcraft.test"
        let rToken = "token-123"
        let appInfo = AppInfo(appID: "app-id", appIID: "iid-xyz", appVer: "1.2.3")

        let result = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: url,
                rToken: rToken,
                appInfo: appInfo
            )
            .build()
        )

        XCTAssertTrue(result, "setConfig must return success")

        guard let entity = sdkFetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist")
            return
        }

        XCTAssertEqual(entity.url, url)
        XCTAssertEqual(entity.rToken, rToken)

        let decodedAppInfo = decodeAppInfoData(entity.appInfo)
        XCTAssertNotNil(decodedAppInfo)
        XCTAssertEqual(decodedAppInfo?.appID, appInfo.appID)
        XCTAssertEqual(decodedAppInfo?.appIID, appInfo.appIID)
        XCTAssertEqual(decodedAppInfo?.appVer, appInfo.appVer)

        let config = await ConfigManager.shared.getConfig()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.apiUrl, url)
        XCTAssertEqual(config?.rToken, rToken)
        XCTAssertEqual(config?.appInfo?.appID, appInfo.appID)
    }

    /// test_2: setConfig updates existing configuration without duplicates
    func test_2_set_config_updates_existing_configuration_without_duplicates() async {
        let firstResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://a1",
                rToken: "rt-1",
                appInfo: AppInfo(appID: "A", appIID: "I", appVer: "1.0")
            )
            .build()
        )

        XCTAssertTrue(firstResult)

        let secondAppInfo = AppInfo(appID: "B", appIID: "J", appVer: "2.0")

        let secondResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://a2",
                rToken: "rt-1",
                appInfo: secondAppInfo
            )
            .build()
        )

        XCTAssertTrue(secondResult)

        let configCount = sdkCount(entityName: Constants.EntityNames.configurationEntity)
        XCTAssertEqual(configCount, 1, "Must keep a single ConfigurationEntity")

        guard let entity = sdkFetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist")
            return
        }

        XCTAssertEqual(entity.url, "https://a2")
        XCTAssertEqual(entity.rToken, "rt-1")

        let decodedAppInfo = decodeAppInfoData(entity.appInfo)
        XCTAssertEqual(decodedAppInfo?.appID, secondAppInfo.appID)
    }

    /// test_3: rToken change check triggers the module purge.
    ///
    /// Android parity (`Init.init` → `RTokenChange.checkRTokenChangedFromInit`):
    /// the comparison against the previously saved token runs after the
    /// configuration is installed; a previously saved token that differs
    /// from the new one notifies the modules.
    func test_3_set_config_token_change_triggers_subscription_purge() async throws {
        // Register module workers so per-module r-token cleanup runs.
        await TestCoreDataStack.registerPurgeModules()
        _ = UpdateAPI.shared

        try sdkSeedSubscribe(count: 5)
        try sdkSeedTargetEvents(count: 3)
        try sdkSeedProfileUpdates(count: 2)

        XCTAssertEqual(sdkCount(entityName: PushConstants.EntityNames.subscribeEntity), 5)
        XCTAssertEqual(sdkCount(entityName: TargetConstants.EntityNames.targetEventEntity), 3)
        XCTAssertEqual(sdkCount(entityName: ProfileConstants.EntityNames.profileUpdateEntity), 2)

        let firstResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "A"
            )
            .build()
        )

        XCTAssertTrue(firstResult)

        // First saved token: no notification.
        await RTokenChange.shared.checkFromConfig()

        XCTAssertEqual(
            sdkCount(entityName: PushConstants.EntityNames.subscribeEntity),
            5,
            "The first saved token must not trigger the purge"
        )

        let secondResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "B"
            )
            .build()
        )

        XCTAssertTrue(secondResult)

        // Previously saved token differs from the new one: notify modules.
        await RTokenChange.shared.checkFromConfig()

        XCTAssertEqual(
            sdkCount(entityName: PushConstants.EntityNames.subscribeEntity),
            0,
            "PushSubscribeEntity must be purged on rToken change"
        )

        XCTAssertEqual(
            sdkCount(entityName: TargetConstants.EntityNames.targetEventEntity),
            0,
            "TargetEntity must be purged on rToken change"
        )

        XCTAssertEqual(
            sdkCount(entityName: ProfileConstants.EntityNames.profileUpdateEntity),
            0,
            "ProfileUpdateEntity must be purged on rToken change"
        )

        await TestCoreDataStack.unregisterPurgeModules()
    }

    /// test_4: getConfig returns nil when URL is empty
    func test_4_get_config_returns_nil_when_url_is_empty() async {
        let context = sdkNewBackgroundContext()
        var insertError: Error?

        context.performAndWait {
            let entity = ConfigurationEntity(context: context)
            entity.url = ""
            entity.rToken = "X"

            do {
                try context.save()
            } catch {
                insertError = error
            }
        }

        XCTAssertNil(insertError, "Insert failed: \(String(describing: insertError))")

        let config = await ConfigManager.shared.getConfig()
        XCTAssertNil(config, "Configuration must be nil if URL is empty")
    }

    /// test_5: doesConfigurationEntityExist returns false then true
    func test_5_does_configuration_entity_exist_returns_false_then_true() async {
        let doesNotExistInitially = await CoreConfigDao().exists()
        XCTAssertFalse(doesNotExistInitially)

        let setResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "R"
            )
            .build()
        )

        XCTAssertTrue(setResult)

        let existsAfterInsert = await CoreConfigDao().exists()
        XCTAssertTrue(existsAfterInsert)
    }

    /// test_6: setConfig with an invalid configuration deletes the stored
    /// entity and returns false
    func test_6_set_config_withInvalidConfiguration_deletesEntity_andReturnsFalse() async {
        let seeded = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "R"
            )
            .build()
        )

        XCTAssertTrue(seeded)

        let result = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(apiUrl: "   ")
                .build()
        )

        XCTAssertFalse(result, "Invalid configuration must not be installed")

        let existsAfterInvalidSet = await CoreConfigDao().exists()
        XCTAssertFalse(
            existsAfterInvalidSet,
            "Invalid configuration must delete the stored configuration entity"
        )

        let config = await ConfigManager.shared.getConfig()
        XCTAssertNil(config)
    }

    /// test_7: setConfig replacing a token with nil (X → nil) does not
    /// trigger the module purge.
    ///
    /// Android parity (`RTokenChange`): a `nil` role token is ignored — it is
    /// neither saved nor notified; dropping the token entirely is not treated
    /// as a change.
    func test_7_set_config_tokenToNil_doesNotTriggerPurge() async throws {
        // Register module workers so per-module r-token cleanup would run.
        await TestCoreDataStack.registerPurgeModules()
        _ = UpdateAPI.shared

        try sdkSeedSubscribe(count: 5)
        try sdkSeedTargetEvents(count: 3)
        try sdkSeedProfileUpdates(count: 2)

        let firstResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "A"
            )
            .build()
        )

        XCTAssertTrue(firstResult)

        let secondResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(apiUrl: "https://api")
                .build()
        )

        XCTAssertTrue(secondResult)

        XCTAssertEqual(
            sdkCount(entityName: PushConstants.EntityNames.subscribeEntity),
            5,
            "PushSubscribeEntity must survive an X → nil transition"
        )

        XCTAssertEqual(
            sdkCount(entityName: TargetConstants.EntityNames.targetEventEntity),
            3,
            "TargetEntity must survive an X → nil transition"
        )

        XCTAssertEqual(
            sdkCount(entityName: ProfileConstants.EntityNames.profileUpdateEntity),
            2,
            "ProfileUpdateEntity must survive an X → nil transition"
        )

        await TestCoreDataStack.unregisterPurgeModules()
    }

    /// test_8: setConfig installing a token when none was stored (nil → X)
    /// does not trigger the module purge.
    ///
    /// Android parity (`RTokenChange`): the first saved token does not
    /// trigger the notification.
    func test_8_set_config_nilToToken_doesNotTriggerPurge() async throws {
        // Register module workers so per-module r-token cleanup would run.
        await TestCoreDataStack.registerPurgeModules()
        _ = UpdateAPI.shared

        try sdkSeedSubscribe(count: 5)
        try sdkSeedTargetEvents(count: 3)
        try sdkSeedProfileUpdates(count: 2)

        let firstResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(apiUrl: "https://api")
                .build()
        )

        XCTAssertTrue(firstResult)

        let secondResult = await ConfigManager.shared.setConfig(
            AltcraftConfiguration.Builder(
                apiUrl: "https://api",
                rToken: "A"
            )
            .build()
        )

        XCTAssertTrue(secondResult)

        XCTAssertEqual(
            sdkCount(entityName: PushConstants.EntityNames.subscribeEntity),
            5,
            "PushSubscribeEntity must survive a nil → X transition"
        )

        XCTAssertEqual(
            sdkCount(entityName: TargetConstants.EntityNames.targetEventEntity),
            3,
            "TargetEntity must survive a nil → X transition"
        )

        XCTAssertEqual(
            sdkCount(entityName: ProfileConstants.EntityNames.profileUpdateEntity),
            2,
            "ProfileUpdateEntity must survive a nil → X transition"
        )

        await TestCoreDataStack.unregisterPurgeModules()
    }
}
