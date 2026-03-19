//
//  ConfigDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
* ConfigDbQueriesTests
*
* Positive scenarios:
* - test_1: setConfig creates new and persists all fields.
* - test_2: setConfig updates existing configuration without duplicates.
* - test_3: setConfig token change triggers subscription purge.
* - test_4: getConfig returns nil when URL is empty.
* - test_5: doesConfigurationEntityExist returns false then true.
* - test_6: updateProviderPriorityList updates list and returns success.
* - test_7: setConfig returns false when DB error status is set.
* - test_8: updateProviderPriorityList returns false when no config exists.
*
*/
final class ConfigDbQueriesTests: IsolatedTestCase {

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

    private var isInMemoryStore: Bool {
        sdkContainer.persistentStoreCoordinator.persistentStores.first?.type == NSInMemoryStoreType
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipe([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ])
    }

    override func tearDownWithError() throws {
        sdkWipe([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ])
        StoredVariablesManager.shared.setCritDB(value: false)
        try super.tearDownWithError()
    }

    private func sdkCount(entityName: String) -> Int? {
        let context = sdkViewContext
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
        let context = sdkNewBackgroundContext()

        context.performAndWait {
            for entityName in entityNames {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.includesPropertyValues = false

                if let objects = try? context.fetch(fetchRequest) as? [NSManagedObject] {
                    objects.forEach { context.delete($0) }
                }
            }

            if context.hasChanges {
                try? context.save()
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

    private func decodeStringArray(_ data: Data?) -> [String]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    private func decodeAppInfoData(_ data: Data?) -> AppInfo? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(AppInfo.self, from: data)
    }

    private func sdkSeedSubscribe(count: Int) throws {
        let context = sdkNewBackgroundContext()
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.subscribeEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigDbQueriesTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity SubscribeEntity not found"]
                )
                return
            }

            for _ in 0..<count {
                _ = NSEntityDescription.insertNewObject(
                    forEntityName: Constants.EntityNames.subscribeEntity,
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

    private func sdkSeedMobileEvents(count: Int) throws {
        let context = sdkNewBackgroundContext()
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.mobileEventEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigDbQueriesTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity MobileEventEntity not found"]
                )
                return
            }

            for index in 0..<count {
                let entity = MobileEventEntity(context: context)
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
        let context = sdkNewBackgroundContext()
        var thrownError: Error?

        context.performAndWait {
            guard NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.profileUpdateEntity,
                in: context
            ) != nil else {
                thrownError = NSError(
                    domain: "ConfigDbQueriesTests",
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
        let providers = [
            Constants.ProviderName.firebase,
            Constants.ProviderName.huawei,
            Constants.ProviderName.apns
        ]

        let result = await setConfig(
            url: url,
            rToken: rToken,
            appInfo: appInfo,
            providerPriorityList: providers
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

        let decodedProviders = decodeStringArray(entity.providerPriorityList)
        XCTAssertEqual(decodedProviders, providers)

        let config = await getConfig()
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.url, url)
        XCTAssertEqual(config?.rToken, rToken)
        XCTAssertEqual(config?.appInfo?.appID, appInfo.appID)
        XCTAssertEqual(config?.providerPriorityList ?? [], providers)
    }

    /// test_2: setConfig updates existing configuration without duplicates
    func test_2_set_config_updates_existing_configuration_without_duplicates() async {
        let firstResult = await setConfig(
            url: "https://a1",
            rToken: "rt-1",
            appInfo: AppInfo(appID: "A", appIID: "I", appVer: "1.0"),
            providerPriorityList: [
                Constants.ProviderName.firebase,
                Constants.ProviderName.huawei
            ]
        )

        XCTAssertTrue(firstResult)

        let secondAppInfo = AppInfo(appID: "B", appIID: "J", appVer: "2.0")
        let secondProviders = [
            Constants.ProviderName.apns,
            Constants.ProviderName.firebase
        ]

        let secondResult = await setConfig(
            url: "https://a2",
            rToken: "rt-1",
            appInfo: secondAppInfo,
            providerPriorityList: secondProviders
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
        XCTAssertEqual(decodeStringArray(entity.providerPriorityList) ?? [], secondProviders)
    }

    /// test_3: setConfig token change triggers subscription purge
    func test_3_set_config_token_change_triggers_subscription_purge() async throws {
        if isInMemoryStore {
            throw XCTSkip("NSBatchDelete may be unsupported by in-memory stores; skipping.")
        }

        try sdkSeedSubscribe(count: 5)
        try sdkSeedMobileEvents(count: 3)
        try sdkSeedProfileUpdates(count: 2)

        XCTAssertEqual(sdkCount(entityName: Constants.EntityNames.subscribeEntity), 5)
        XCTAssertEqual(sdkCount(entityName: Constants.EntityNames.mobileEventEntity), 3)
        XCTAssertEqual(sdkCount(entityName: Constants.EntityNames.profileUpdateEntity), 2)

        let firstResult = await setConfig(
            url: "https://api",
            rToken: "A",
            appInfo: nil,
            providerPriorityList: nil
        )

        XCTAssertTrue(firstResult)

        let secondResult = await setConfig(
            url: "https://api",
            rToken: "B",
            appInfo: nil,
            providerPriorityList: nil
        )

        XCTAssertTrue(secondResult)

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.subscribeEntity),
            0,
            "SubscribeEntity must be purged on rToken change"
        )

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.mobileEventEntity),
            0,
            "MobileEventEntity must be purged on rToken change"
        )

        XCTAssertEqual(
            sdkCount(entityName: Constants.EntityNames.profileUpdateEntity),
            0,
            "ProfileUpdateEntity must be purged on rToken change"
        )
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

        let config = await getConfig()
        XCTAssertNil(config, "Configuration must be nil if URL is empty")
    }

    /// test_5: doesConfigurationEntityExist returns false then true
    func test_5_does_configuration_entity_exist_returns_false_then_true() async {
        let doesNotExistInitially = await doesConfigurationEntityExist()
        XCTAssertFalse(doesNotExistInitially)

        let setResult = await setConfig(
            url: "https://api",
            rToken: "R",
            appInfo: nil,
            providerPriorityList: nil
        )

        XCTAssertTrue(setResult)

        let existsAfterInsert = await doesConfigurationEntityExist()
        XCTAssertTrue(existsAfterInsert)
    }

    /// test_6: updateProviderPriorityList updates list and returns success
    func test_6_update_provider_priority_list_updates_list_and_returns_success() async {
        let setResult = await setConfig(
            url: "https://api",
            rToken: "R",
            appInfo: nil,
            providerPriorityList: [Constants.ProviderName.firebase]
        )

        XCTAssertTrue(setResult)

        let newList = [
            Constants.ProviderName.apns,
            Constants.ProviderName.huawei,
            Constants.ProviderName.firebase
        ]

        let updateResult = await updateProviderPriorityList(newList: newList)
        XCTAssertTrue(updateResult)

        guard let entity = sdkFetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist")
            return
        }

        XCTAssertEqual(decodeStringArray(entity.providerPriorityList) ?? [], newList)
    }

    /// test_7: setConfig returns false when DB error status is set
    func test_7_set_config_returns_false_when_db_error_status_is_set() async {
        StoredVariablesManager.shared.setCritDB(value: true)

        let result = await setConfig(
            url: "https://api",
            rToken: "token",
            appInfo: nil,
            providerPriorityList: nil
        )

        XCTAssertFalse(result, "setConfig should return false when DB error status is set")

        StoredVariablesManager.shared.setCritDB(value: false)
    }

    /// test_8: updateProviderPriorityList returns false when no config exists
    func test_8_update_provider_priority_list_returns_false_when_no_config_exists() async {
        sdkWipe([
            Constants.EntityNames.configurationEntity,
            Constants.EntityNames.subscribeEntity,
            Constants.EntityNames.mobileEventEntity,
            Constants.EntityNames.profileUpdateEntity
        ])

        let result = await updateProviderPriorityList(
            newList: [Constants.ProviderName.apns]
        )

        XCTAssertFalse(result, "Should return false when no configuration exists")
    }
}
