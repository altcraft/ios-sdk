//
//  ConfigDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * ConfigDbQueriesTests (iOS 13 compatible)
 *
 * Positive scenarios:
 *  - test_1_setConfig_createsNew_andPersistsAllFields:
 *      setConfig creates a new ConfigurationEntity, persists url and rToken,
 *      encodes AppInfo and providerPriorityList to Data, and getConfigFromCoreData
 *      returns a populated Configuration with the same values.
 *
 *  - test_2_setConfig_updatesExisting_noDuplicates:
 *      calling setConfig again with the same rToken updates the existing row in place,
 *      keeps exactly one ConfigurationEntity, and reflects the latest url/appInfo/providerPriorityList.
 *      No subscription purge is expected because rToken did not change.
 *
 *  - test_3_setConfig_tokenChange_triggersSubscriptionPurge:
 *      when rToken changes, setConfig performs an NSBatchDelete over SubscribeEntity
 *      so that all previously stored subscriptions are purged.
 *
 *  - test_5_doesConfigurationEntityExist_false_then_true:
 *      doesConfigurationEntityExist returns false when there is no configuration,
 *      then returns true after setConfig creates one.
 *
 *  - test_6_updateProviderPriorityList_updatesList_andReturnsSuccess:
 *      updateProviderPriorityList replaces the stored providerPriorityList Data with the new order
 *      and completes with .success; persisted bytes decode back to the provided String array.
 *
 * Edge scenarios:
 *  - test_4_getConfigFromCoreData_returnsNil_whenUrlEmpty:
 *      if the stored ConfigurationEntity has an empty url, getConfigFromCoreData
 *      returns nil due to configFromEntity guard that filters out invalid configurations.
 *
 * Notes:
 *  - Uses CoreDataManager.shared.persistentContainer (production stack, no seams).
 *  - No assumption about completion thread: production calls may complete on a background queue,
 *    so tests do not assert main-thread callbacks.
 *  - Each test cleans up only the necessary entities via NSBatchDelete (best-effort).
 *  - iOS 13 compatible: uses non-throwing performAndWait and manual error capture where needed.
 */
final class ConfigDbQueriesTests: XCTestCase {

    // MARK: - Constants

    private let timeoutShort: TimeInterval = 2.5
    private let timeoutLong:  TimeInterval = 4.0

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        wipeEntities([Constants.EntityNames.configEntityName,
                      Constants.EntityNames.subscribeEntityName])
    }

    override func tearDown() {
        wipeEntities([Constants.EntityNames.configEntityName,
                      Constants.EntityNames.subscribeEntityName])
        super.tearDown()
    }

    // MARK: - Helpers

    /// Returns number of objects for an entity name, or nil on failure.
    private func count(entityName: String) -> Int? {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.viewContext
        var result: Int?
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fr.includesSubentities = true
            do { result = try ctx.count(for: fr) } catch { result = nil }
        }
        return result
    }

    /// Batch-deletes provided entities. Best-effort (no hard failure on errors).
    private func wipeEntities(_ entityNames: [String]) {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        bg.performAndWait {
            for name in entityNames {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                let req = NSBatchDeleteRequest(fetchRequest: fr)
                req.resultType = .resultTypeObjectIDs
                do {
                    if let res = try bg.execute(req) as? NSBatchDeleteResult,
                       let oids = res.result as? [NSManagedObjectID] {
                        NSManagedObjectContext.mergeChanges(
                            fromRemoteContextSave: [NSDeletedObjectsKey: oids],
                            into: [container.viewContext, bg]
                        )
                    }
                } catch {
                    // best-effort cleanup
                }
            }
            if bg.hasChanges { try? bg.save() }
        }
    }

    /// Fetches the single ConfigurationEntity if present.
    private func fetchSingleConfigurationEntity() -> ConfigurationEntity? {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.viewContext
        var obj: ConfigurationEntity?
        ctx.performAndWait {
            let fr: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            fr.fetchLimit = 1
            obj = try? ctx.fetch(fr).first
        }
        return obj
    }

    /// Decodes [String] from Data?.
    private func decodeStringArray(_ data: Data?) -> [String]? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode([String].self, from: d)
    }

    /// Decodes AppInfo from Data?.
    private func decodeAppInfoData(_ data: Data?) -> AppInfo? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(AppInfo.self, from: d)
    }

    /// Seeds N empty SubscribeEntity rows.
    private func seedSubscribe(count n: Int) throws {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        var thrown: Error?
        bg.performAndWait {
            guard let _ = NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.subscribeEntityName, in: bg
            ) else {
                thrown = NSError(domain: "ConfigDbQueriesTests", code: 404,
                                 userInfo: [NSLocalizedDescriptionKey: "Entity SubscribeEntity not found"])
                return
            }
            for _ in 0..<n {
                _ = NSEntityDescription.insertNewObject(
                    forEntityName: Constants.EntityNames.subscribeEntityName, into: bg
                )
            }
            do { try bg.save() } catch { thrown = error }
        }
        if let e = thrown { throw e }
    }

    // MARK: - Tests

    /// Create a new configuration and assert fields persisted correctly.
    func test_1_setConfig_createsNew_andPersistsAllFields() {
        let url = "https://api.altcraft.test"
        let rToken = "token-123"
        let app = AppInfo(appID: "app-id", appIID: "iid-xyz", appVer: "1.2.3")
        let providers = ["FCM", "HMS", "APNs"]

        let exp = expectation(description: "setConfig completion")
        setConfig(url: url, rToken: rToken, appInfo: app, providerPriorityList: providers) { ok in
            XCTAssertTrue(ok, "setConfig must return success")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        guard let e = fetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist"); return
        }
        XCTAssertEqual(e.url, url)
        XCTAssertEqual(e.rToken, rToken)

        let decodedApp = decodeAppInfoData(e.appInfo)
        XCTAssertNotNil(decodedApp)
        XCTAssertEqual(decodedApp?.appID, app.appID)
        XCTAssertEqual(decodedApp?.appIID, app.appIID)
        XCTAssertEqual(decodedApp?.appVer, app.appVer)

        let decodedProviders = decodeStringArray(e.providerPriorityList)
        XCTAssertEqual(decodedProviders, providers)

        let exp2 = expectation(description: "getConfigFromCoreData")
        getConfigFromCoreData { cfg in
            XCTAssertNotNil(cfg)
            XCTAssertEqual(cfg?.url, url)
            XCTAssertEqual(cfg?.rToken, rToken)
            XCTAssertEqual(cfg?.appInfo?.appID, app.appID)
            XCTAssertEqual(cfg?.providerPriorityList ?? [], providers)
            exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// Update existing config in-place, keep single row, and verify updated values.
    func test_2_setConfig_updatesExisting_noDuplicates() {
        // Initial
        let url1 = "https://a1"
        let r1 = "rt-1"
        let app1 = AppInfo(appID: "A", appIID: "I", appVer: "1.0")
        let p1 = ["FCM", "HMS"]

        let exp1 = expectation(description: "setConfig 1")
        setConfig(url: url1, rToken: r1, appInfo: app1, providerPriorityList: p1) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        // Update (same token -> no subscription purge)
        let url2 = "https://a2"
        let app2 = AppInfo(appID: "B", appIID: "J", appVer: "2.0")
        let p2 = ["APNs", "FCM"]

        let exp2 = expectation(description: "setConfig 2")
        setConfig(url: url2, rToken: r1, appInfo: app2, providerPriorityList: p2) { ok in
            XCTAssertTrue(ok); exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let cfgCount = count(entityName: Constants.EntityNames.configEntityName)
        XCTAssertEqual(cfgCount, 1, "Must keep a single ConfigurationEntity")

        guard let e = fetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist"); return
        }
        XCTAssertEqual(e.url, url2)
        XCTAssertEqual(e.rToken, r1)
        let appDec = decodeAppInfoData(e.appInfo)
        XCTAssertEqual(appDec?.appID, app2.appID)
        XCTAssertEqual(decodeStringArray(e.providerPriorityList) ?? [], p2)
    }

    /// rToken change triggers NSBatchDelete over SubscribeEntity.
    func test_3_setConfig_tokenChange_triggersSubscriptionPurge() throws {
        try seedSubscribe(count: 5)
        XCTAssertEqual(count(entityName: Constants.EntityNames.subscribeEntityName), 5)

        // Create with token A
        let exp1 = expectation(description: "setConfig A")
        setConfig(url: "https://api", rToken: "A", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        // Change to token B -> should purge subscriptions
        let exp2 = expectation(description: "setConfig B")
        setConfig(url: "https://api", rToken: "B", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertTrue(ok); exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(count(entityName: Constants.EntityNames.subscribeEntityName), 0,
                       "SubscribeEntity must be purged on rToken change")
    }

    /// getConfigFromCoreData returns nil when url is empty (configFromEntity guard).
    func test_4_getConfigFromCoreData_returnsNil_whenUrlEmpty() {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()
        var insertError: Error?
        bg.performAndWait {
            let e = ConfigurationEntity(context: bg)
            e.url = ""      // empty url -> filtered by configFromEntity
            e.rToken = "X"
            do { try bg.save() } catch { insertError = error }
        }
        XCTAssertNil(insertError, "Insert failed: \(String(describing: insertError))")

        let exp = expectation(description: "getConfigFromCoreData empty url")
        getConfigFromCoreData { cfg in
            XCTAssertNil(cfg, "Configuration must be nil if url is empty")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// doesConfigurationEntityExist: false -> true.
    func test_5_doesConfigurationEntityExist_false_then_true() {
        let exp1 = expectation(description: "exist false")
        doesConfigurationEntityExist(resToken: "any") { result in
            switch result {
            case .success(let exists): XCTAssertFalse(exists)
            case .failure(let e): XCTFail("Unexpected error: \(e)")
            }
            exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let exp2 = expectation(description: "setConfig")
        setConfig(url: "https://api", rToken: "R", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertTrue(ok); exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let exp3 = expectation(description: "exist true")
        doesConfigurationEntityExist(resToken: "ignored") { result in
            switch result {
            case .success(let exists): XCTAssertTrue(exists)
            case .failure(let e): XCTFail("Unexpected error: \(e)")
            }
            exp3.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// updateProviderPriorityList updates Data and returns .success.
    func test_6_updateProviderPriorityList_updatesList_andReturnsSuccess() {
        let exp1 = expectation(description: "setConfig")
        setConfig(url: "https://api", rToken: "R", appInfo: nil, providerPriorityList: ["FCM"]) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let newList = ["APNs", "HMS", "FCM"]
        let exp2 = expectation(description: "update list")
        updateProviderPriorityList(newList: newList) { result in
            switch result {
            case .success: exp2.fulfill()
            case .failure(let e): XCTFail("updateProviderPriorityList failed: \(e)")
            }
        }
        waitForExpectations(timeout: timeoutShort)

        guard let e = fetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist"); return
        }
        XCTAssertEqual(decodeStringArray(e.providerPriorityList) ?? [], newList)
    }
}

