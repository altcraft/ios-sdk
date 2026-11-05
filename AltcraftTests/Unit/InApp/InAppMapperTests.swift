//
//  InAppMapperTests.swift
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
 * InAppMapperTests
 *
 * Positive scenarios:
 *  - test_1: toInApp merges rawInApp and rawPlacement correctly.
 *  - test_2: toInApp takes first trigger event from placement.
 *  - test_3: toInApp sets isTest to false.
 *  - test_4: rawToTestInApp creates test model with defaults.
 *  - test_5: rawToTestInApp sets isTest to true.
 *  - test_6: rawToTestInApp sets actionTriggerType to custom.
 *  - test_7: toInApp with no trigger events uses empty name.
 *  - test_8: apply encodes nested values as JSON data.
 *  - test_9: toInApp from entity decodes JSON data correctly.
 *  - test_10: round-trip apply then decode preserves values.
 *
 * Edge scenarios:
 *  - test_11: toInApp from entity with nil strings defaults to empty.
 *  - test_12: toInApp from entity always sets isTest to false.
 */
final class InAppMapperTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override class var sdkManagerContainer: NSPersistentContainer? {
        inAppDatabase.persistentContainer
    }

    private func makeRawInApp(
        companyId: Int = 1,
        smid: String = "smid-1",
        type: String = "custom",
        contentUrl: String = "https://example.com",
        deadline: Int64 = 0,
        lastCompanyUpdate: Int64 = 1000
    ) -> InAppModel.RawInApp {
        InAppModel.RawInApp(
            companyId: companyId,
            contentUrl: contentUrl,
            isTest: nil,
            smid: smid,
            type: type,
            deadline: deadline,
            lastCompanyUpdate: lastCompanyUpdate
        )
    }

    private func makeRawPlacement(
        id: Int = 1,
        checksum: String = "chk-1",
        options: InAppModel.PlacementOptions
    ) -> InAppModel.RawPlacement {
        InAppModel.RawPlacement(id: id, checksum: checksum, options: options)
    }

    /// test_1: toInApp merges rawInApp and rawPlacement correctly
    func test_1_toInApp_mergesRawInAppAndPlacement() {
        let rawInApp = makeRawInApp()
        let options = InAppModel.PlacementOptions(
            endTime: 5000,
            policy: InAppModel.Policy(limitBySession: 3),
            priority: 5,
            triggerEvents: [InAppModel.TriggerEvent(type: "custom", name: "evt", delay: 0)]
        )
        let rawPlacement = makeRawPlacement(options: options)

        let inApp = InAppMapper.toInApp(rawInApp: rawInApp, rawPlacement: rawPlacement)

        XCTAssertEqual(inApp.companyId, 1)
        XCTAssertEqual(inApp.smid, "smid-1")
        XCTAssertEqual(inApp.type, "custom")
        XCTAssertEqual(inApp.contentUrl, "https://example.com")
        XCTAssertEqual(inApp.checksum, "chk-1")
        XCTAssertEqual(inApp.options.endTime, 5000)
        XCTAssertEqual(inApp.options.priority, 5)
        XCTAssertEqual(inApp.deadline, 0)
        XCTAssertEqual(inApp.lastCompanyUpdate, 1000)
    }

    /// test_2: toInApp takes first trigger event from placement
    func test_2_toInApp_takesFirstTrigger() {
        let rawInApp = makeRawInApp()
        let options = InAppModel.PlacementOptions(
            endTime: 0,
            triggerEvents: [
                InAppModel.TriggerEvent(type: "custom", name: "first", delay: 0),
                InAppModel.TriggerEvent(type: "default", name: "second", delay: 10)
            ]
        )
        let rawPlacement = makeRawPlacement(options: options)

        let inApp = InAppMapper.toInApp(rawInApp: rawInApp, rawPlacement: rawPlacement)

        XCTAssertEqual(inApp.actionTriggerName, "first")
        XCTAssertEqual(inApp.actionTriggerType, .custom)
    }

    /// test_3: toInApp sets isTest to false
    func test_3_toInApp_setsIsTestFalse() {
        let rawInApp = makeRawInApp()
        let options = InAppModel.PlacementOptions(endTime: 0)
        let rawPlacement = makeRawPlacement(options: options)

        let inApp = InAppMapper.toInApp(rawInApp: rawInApp, rawPlacement: rawPlacement)
        XCTAssertFalse(inApp.isTest)
    }

    /// test_4: rawToTestInApp creates test model with defaults
    func test_4_rawToTestInApp_createsWithDefaults() {
        let rawInApp = makeRawInApp()
        let inApp = InAppMapper.rawToTestInApp(rawInApp)

        XCTAssertEqual(inApp.companyId, 1)
        XCTAssertEqual(inApp.smid, "smid-1")
        XCTAssertEqual(inApp.checksum, "")
        XCTAssertEqual(inApp.options.endTime, 0)
        XCTAssertNil(inApp.options.policy)
        XCTAssertTrue(inApp.options.placements.isEmpty)
        XCTAssertTrue(inApp.options.triggerEvents.isEmpty)
        XCTAssertEqual(inApp.options.priority, 0)
    }

    /// test_5: rawToTestInApp sets isTest to true
    func test_5_rawToTestInApp_setsIsTestTrue() {
        let rawInApp = makeRawInApp()
        let inApp = InAppMapper.rawToTestInApp(rawInApp)
        XCTAssertTrue(inApp.isTest)
    }

    /// test_6: rawToTestInApp sets actionTriggerType to custom
    func test_6_rawToTestInApp_setsActionTriggerTypeCustom() {
        let rawInApp = makeRawInApp()
        let inApp = InAppMapper.rawToTestInApp(rawInApp)
        XCTAssertEqual(inApp.actionTriggerType, .custom)
        XCTAssertEqual(inApp.actionTriggerName, "")
    }

    /// test_7: toInApp with no trigger events uses empty name
    func test_7_toInApp_noTriggers_emptyName() {
        let rawInApp = makeRawInApp()
        let options = InAppModel.PlacementOptions(endTime: 0, triggerEvents: [])
        let rawPlacement = makeRawPlacement(options: options)

        let inApp = InAppMapper.toInApp(rawInApp: rawInApp, rawPlacement: rawPlacement)
        XCTAssertEqual(inApp.actionTriggerName, "")
    }

    /// test_8: apply encodes nested values as JSON data
    func test_8_apply_encodesNestedValues() throws {
        guard NSClassFromString("InAppEntity") != nil else {
            throw XCTSkip("InAppEntity not available")
        }

        let inApp = InAppModel.InApp(
            uid: "u1", companyId: 1, smid: "s1", type: "custom",
            contentUrl: "http://x", checksum: "c",
            options: InAppModel.PlacementOptions(
                endTime: 100,
                policy: InAppModel.Policy(limitBySession: 2, limitByTrigger: 3, minIntervalSec: 60),
                placements: ["home"],
                appVersions: ["1.0.0"],
                priority: 5,
                triggerEvents: [InAppModel.TriggerEvent(type: "custom", name: "t", delay: 10)]
            ),
            deadline: 200, isTest: false, lastCompanyUpdate: 300,
            actionTriggerName: "t", actionTriggerType: .custom
        )

        let entity = InAppEntity(context: viewContext)
        try InAppMapper.apply(inApp, to: entity)

        XCTAssertEqual(entity.uid, "u1")
        XCTAssertEqual(entity.companyId, 1)
        XCTAssertEqual(entity.smid, "s1")
        XCTAssertEqual(entity.deadline, 200)
        XCTAssertEqual(entity.lastCompanyUpdate, 300)
        XCTAssertEqual(entity.actionTriggerName, "t")
        XCTAssertEqual(Int(entity.priority), 5)
        XCTAssertEqual(entity.endDate, 100)

        XCTAssertNotNil(entity.placements)
        XCTAssertNotNil(entity.triggerEvents)
        XCTAssertNotNil(entity.policy)
    }

    /// test_9: toInApp from entity decodes JSON data correctly
    func test_9_toInAppFromEntity_decodesJSON() throws {
        guard NSClassFromString("InAppEntity") != nil else {
            throw XCTSkip("InAppEntity not available")
        }

        let placements = try encodeInAppValue(["home", "settings"])
        let triggers = try encodeInAppValue([InAppModel.TriggerEvent(type: "custom", name: "t", delay: 5)])
        let policy = try encodeInAppValue(InAppModel.Policy(limitBySession: 2))

        let entity = InAppEntity(context: viewContext)
        entity.uid = "u1"
        entity.companyId = 1
        entity.smid = "s1"
        entity.type = "custom"
        entity.contentUrl = "http://x"
        entity.checksum = "c"
        entity.deadline = 200
        entity.lastCompanyUpdate = 300
        entity.actionTriggerName = "t"
        entity.actionTriggerType = "custom"
        entity.priority = 5
        entity.endDate = 100
        entity.placements = placements
        entity.triggerEvents = triggers
        entity.policy = policy
        try viewContext.save()

        let inApp = try InAppMapper.toInApp(entity: entity)

        XCTAssertEqual(inApp.uid, "u1")
        XCTAssertEqual(inApp.companyId, 1)
        XCTAssertEqual(inApp.options.placements, ["home", "settings"])
        XCTAssertEqual(inApp.options.triggerEvents.count, 1)
        XCTAssertEqual(inApp.options.triggerEvents.first?.name, "t")
        XCTAssertEqual(inApp.options.triggerEvents.first?.delay, 5)
        XCTAssertEqual(inApp.options.policy?.limitBySession, 2)
        XCTAssertEqual(inApp.options.priority, 5)
    }

    /// test_10: round-trip apply then decode preserves values
    func test_10_roundTrip_applyThenDecode() throws {
        guard NSClassFromString("InAppEntity") != nil else {
            throw XCTSkip("InAppEntity not available")
        }

        let original = InAppModel.InApp(
            uid: "rt-1", companyId: 42, smid: "s-rt", type: "json",
            contentUrl: "https://example.com/page", checksum: "chk-rt",
            options: InAppModel.PlacementOptions(
                endTime: 999,
                policy: InAppModel.Policy(limitBySession: 5, limitByTrigger: 10, minIntervalSec: 120),
                placements: ["a", "b"],
                appVersions: ["2.0.0"],
                priority: 7,
                triggerEvents: [
                    InAppModel.TriggerEvent(type: "default", name: "openApp", delay: 0),
                    InAppModel.TriggerEvent(type: "custom", name: "buy", delay: 30)
                ]
            ),
            deadline: 5000, isTest: false, lastCompanyUpdate: 4000,
            actionTriggerName: "openApp", actionTriggerType: .default
        )

        let entity = InAppEntity(context: viewContext)
        try InAppMapper.apply(original, to: entity)
        try viewContext.save()

        let restored = try InAppMapper.toInApp(entity: entity)

        XCTAssertEqual(restored.uid, original.uid)
        XCTAssertEqual(restored.companyId, original.companyId)
        XCTAssertEqual(restored.smid, original.smid)
        XCTAssertEqual(restored.type, original.type)
        XCTAssertEqual(restored.contentUrl, original.contentUrl)
        XCTAssertEqual(restored.checksum, original.checksum)
        XCTAssertEqual(restored.deadline, original.deadline)
        XCTAssertEqual(restored.lastCompanyUpdate, original.lastCompanyUpdate)
        XCTAssertEqual(restored.actionTriggerName, original.actionTriggerName)
        XCTAssertEqual(restored.actionTriggerType, original.actionTriggerType)
        XCTAssertEqual(restored.options.placements, original.options.placements)
        XCTAssertEqual(restored.options.appVersions, original.options.appVersions)
        XCTAssertEqual(restored.options.priority, original.options.priority)
        XCTAssertEqual(restored.options.triggerEvents.count, original.options.triggerEvents.count)
        XCTAssertEqual(restored.options.policy?.limitBySession, original.options.policy?.limitBySession)
        XCTAssertEqual(restored.options.policy?.limitByTrigger, original.options.policy?.limitByTrigger)
        XCTAssertEqual(restored.options.policy?.minIntervalSec, original.options.policy?.minIntervalSec)
    }

    /// test_11: toInApp from entity with nil strings defaults to empty
    func test_11_toInAppFromEntity_nilStrings_defaultEmpty() throws {
        guard NSClassFromString("InAppEntity") != nil else {
            throw XCTSkip("InAppEntity not available")
        }

        let entity = InAppEntity(context: viewContext)
        entity.uid = nil
        entity.smid = nil
        entity.type = nil
        entity.contentUrl = nil
        entity.checksum = nil
        entity.actionTriggerName = nil
        entity.actionTriggerType = ""
        try viewContext.save()

        let inApp = try InAppMapper.toInApp(entity: entity)

        XCTAssertEqual(inApp.uid, "")
        XCTAssertEqual(inApp.smid, "")
        XCTAssertEqual(inApp.type, "")
        XCTAssertEqual(inApp.contentUrl, "")
        XCTAssertEqual(inApp.checksum, "")
        XCTAssertEqual(inApp.actionTriggerName, "")
    }

    /// test_12: toInApp from entity always sets isTest to false
    func test_12_toInAppFromEntity_isTestAlwaysFalse() throws {
        guard NSClassFromString("InAppEntity") != nil else {
            throw XCTSkip("InAppEntity not available")
        }

        let entity = InAppEntity(context: viewContext)
        try viewContext.save()

        let inApp = try InAppMapper.toInApp(entity: entity)
        XCTAssertFalse(inApp.isTest)
    }
}
