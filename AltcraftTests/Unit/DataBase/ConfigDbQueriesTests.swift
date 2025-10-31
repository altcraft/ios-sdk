//
//  ConfigDbQueriesTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * ConfigDbQueriesTests
 *
 * Positive scenarios:
 *  - test_1: Set config creates new and persists all fields.
 *  - test_2: Set config updates existing no duplicates.
 *  - test_3: Set config token change triggers subscription purge.
 *  - test_4: Get config returns nil when URL empty.
 *  - test_5: Does configuration entity exist false then true.
 *  - test_6: Update provider priority list updates list and returns success.
 *  - test_7: Set config returns false when DB error status is set.
 *  - test_8: Update provider priority list returns error when no config.
 */
final class ConfigDbQueriesTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    private var sdkContainer: NSPersistentContainer { CoreDataManager.shared.persistentContainer }
    private var sdkViewContext: NSManagedObjectContext { sdkContainer.viewContext }

    private func sdkNewBG() -> NSManagedObjectContext {
        let ctx = sdkContainer.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        ctx.undoManager = nil
        return ctx
    }

    private var isInMemoryStore: Bool {
        sdkContainer.persistentStoreCoordinator.persistentStores.first?.type == NSInMemoryStoreType
    }

    private let timeoutShort: TimeInterval = 2.5

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipe([Constants.EntityNames.config, Constants.EntityNames.subscribe])
    }

    override func tearDownWithError() throws {
        sdkWipe([Constants.EntityNames.config, Constants.EntityNames.subscribe])
        try super.tearDownWithError()
    }

    private func sdkCount(entityName: String) -> Int? {
        let ctx = sdkViewContext
        var result: Int?
        ctx.performAndWait {
            let fr = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fr.includesSubentities = true
            do { result = try ctx.count(for: fr) } catch { result = nil }
        }
        return result
    }

    private func sdkWipe(_ entityNames: [String]) {
        let bg = sdkNewBG()
        bg.performAndWait {
            for name in entityNames {
                let fr = NSFetchRequest<NSFetchRequestResult>(entityName: name)
                fr.includesPropertyValues = false
                if let objects = try? bg.fetch(fr) as? [NSManagedObject] {
                    objects.forEach { bg.delete($0) }
                }
            }
            if bg.hasChanges { try? bg.save() }
        }
    }

    private func sdkFetchSingleConfigurationEntity() -> ConfigurationEntity? {
        let ctx = sdkViewContext
        var obj: ConfigurationEntity?
        ctx.performAndWait {
            let fr: NSFetchRequest<ConfigurationEntity> = ConfigurationEntity.fetchRequest()
            fr.fetchLimit = 1
            obj = try? ctx.fetch(fr).first
        }
        return obj
    }

    private func decodeStringArray(_ data: Data?) -> [String]? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode([String].self, from: d)
    }

    private func decodeAppInfoData(_ data: Data?) -> AppInfo? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(AppInfo.self, from: d)
    }

    private func sdkSeedSubscribe(count n: Int) throws {
        let bg = sdkNewBG()
        var thrown: Error?
        bg.performAndWait {
            guard let _ = NSEntityDescription.entity(
                forEntityName: Constants.EntityNames.subscribe, in: bg
            ) else {
                thrown = NSError(domain: "ConfigDbQueriesTests", code: 404,
                                 userInfo: [NSLocalizedDescriptionKey: "Entity SubscribeEntity not found"])
                return
            }
            for _ in 0..<n {
                _ = NSEntityDescription.insertNewObject(
                    forEntityName: Constants.EntityNames.subscribe, into: bg
                )
            }
            do { try bg.save() } catch { thrown = error }
        }
        if let e = thrown { throw e }
    }

    /// test_1: Set config creates new and persists all fields
    func test_1_setConfig_createsNew_andPersistsAllFields() {
        let url = "https://api.altcraft.test"
        let rToken = "token-123"
        let app = AppInfo(appID: "app-id", appIID: "iid-xyz", appVer: "1.2.3")
        let providers = [Constants.ProviderName.firebase, Constants.ProviderName.huawei, Constants.ProviderName.apns]

        let exp = expectation(description: "setConfig completion")
        setConfig(url: url, rToken: rToken, appInfo: app, providerPriorityList: providers) { ok in
            XCTAssertTrue(ok, "setConfig must return success")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        guard let e = sdkFetchSingleConfigurationEntity() else {
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

        let exp2 = expectation(description: "getConfig")
        getConfig { cfg in
            XCTAssertNotNil(cfg)
            XCTAssertEqual(cfg?.url, url)
            XCTAssertEqual(cfg?.rToken, rToken)
            XCTAssertEqual(cfg?.appInfo?.appID, app.appID)
            XCTAssertEqual(cfg?.providerPriorityList ?? [], providers)
            exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_2: Set config updates existing no duplicates
    func test_2_setConfig_updatesExisting_noDuplicates() {
        let url1 = "https://a1"
        let r1 = "rt-1"
        let app1 = AppInfo(appID: "A", appIID: "I", appVer: "1.0")
        let p1 = [Constants.ProviderName.firebase, Constants.ProviderName.huawei]

        let exp1 = expectation(description: "setConfig 1")
        setConfig(url: url1, rToken: r1, appInfo: app1, providerPriorityList: p1) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let url2 = "https://a2"
        let app2 = AppInfo(appID: "B", appIID: "J", appVer: "2.0")
        let p2 = [Constants.ProviderName.apns, Constants.ProviderName.firebase]

        let exp2 = expectation(description: "setConfig 2")
        setConfig(url: url2, rToken: r1, appInfo: app2, providerPriorityList: p2) { ok in
            XCTAssertTrue(ok); exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let cfgCount = sdkCount(entityName: Constants.EntityNames.config)
        XCTAssertEqual(cfgCount, 1, "Must keep a single ConfigurationEntity")

        guard let e = sdkFetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist"); return
        }
        XCTAssertEqual(e.url, url2)
        XCTAssertEqual(e.rToken, r1)
        let appDec = decodeAppInfoData(e.appInfo)
        XCTAssertEqual(appDec?.appID, app2.appID)
        XCTAssertEqual(decodeStringArray(e.providerPriorityList) ?? [], p2)
    }

    /// test_3: Set config token change triggers subscription purge
    func test_3_setConfig_tokenChange_triggersSubscriptionPurge() throws {
        if isInMemoryStore {
            throw XCTSkip("NSBatchDelete may be unsupported by in-memory stores; skipping.")
        }

        try sdkSeedSubscribe(count: 5)
        XCTAssertEqual(sdkCount(entityName: Constants.EntityNames.subscribe), 5)

        let exp1 = expectation(description: "setConfig A")
        setConfig(url: "https://api", rToken: "A", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let exp2 = expectation(description: "setConfig B")
        setConfig(url: "https://api", rToken: "B", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertTrue(ok); exp2.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        XCTAssertEqual(sdkCount(entityName: Constants.EntityNames.subscribe), 0,
                       "SubscribeEntity must be purged on rToken change.")
    }

    /// test_4: Get config returns nil when URL empty
    func test_4_getConfig_returnsNil_whenUrlEmpty() {
        let bg = sdkNewBG()
        var insertError: Error?
        bg.performAndWait {
            let e = ConfigurationEntity(context: bg)
            e.url = ""
            e.rToken = "X"
            do { try bg.save() } catch { insertError = error }
        }
        XCTAssertNil(insertError, "Insert failed: \(String(describing: insertError))")

        let exp = expectation(description: "getConfig empty url")
        getConfig { cfg in
            XCTAssertNil(cfg, "Configuration must be nil if url is empty")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }

    /// test_5: Does configuration entity exist false then true
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

    /// test_6: Update provider priority list updates list and returns success
    func test_6_updateProviderPriorityList_updatesList_andReturnsSuccess() {
        let exp1 = expectation(description: "setConfig")
        setConfig(url: "https://api", rToken: "R",
                  appInfo: nil, providerPriorityList: [Constants.ProviderName.firebase]) { ok in
            XCTAssertTrue(ok); exp1.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let newList = [Constants.ProviderName.apns, Constants.ProviderName.huawei, Constants.ProviderName.firebase]
        let exp2 = expectation(description: "update list")
        updateProviderPriorityList(newList: newList) { result in
            switch result {
            case .success: exp2.fulfill()
            case .failure(let e): XCTFail("updateProviderPriorityList failed: \(e)")
            }
        }
        waitForExpectations(timeout: timeoutShort)

        guard let e = sdkFetchSingleConfigurationEntity() else {
            XCTFail("ConfigurationEntity must exist"); return
        }
        XCTAssertEqual(decodeStringArray(e.providerPriorityList) ?? [], newList)
    }

    /// test_7: Set config returns false when DB error status is set
    func test_7_setConfig_returnsFalse_whenDbErrorStatusIsSet() {
        StoredVariablesManager.shared.setCritDB(value: true)

        let exp = expectation(description: "setConfig with DB error")
        setConfig(url: "https://api", rToken: "token", appInfo: nil, providerPriorityList: nil) { ok in
            XCTAssertFalse(ok, "setConfig should return false when DB error status is set")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        StoredVariablesManager.shared.setCritDB(value: false)
    }

    /// test_8: Update provider priority list returns error when no config
    func test_8_updateProviderPriorityList_returnsError_whenNoConfig() {
        sdkWipe([Constants.EntityNames.config, Constants.EntityNames.subscribe])

        let exp = expectation(description: "update list with no config")
        updateProviderPriorityList(newList: [Constants.ProviderName.apns]) { result in
            switch result {
            case .success:
                XCTFail("Should return error when no configuration exists")
            case .failure:
                break
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)
    }
}
