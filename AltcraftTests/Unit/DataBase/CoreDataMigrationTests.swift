//
//  CoreDataMigrationTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * CoreDataMigrationTests
 *
 * Positive scenarios:
 *  - test_1: Oldest→Current: if store is incompatible → migrate; if compatible → no-op; current model opens store.
 *  - test_2: Pairwise across all steps: for each step expect migrate-or-compatible; current model opens store.
 *  - test_3: Current→Current: strictly no-op and current model opens store.
 */
final class CoreDataMigrationTests: XCTestCase {

    private let msgNil:     String = "Value must be nil"
    private let msgNonNil:  String = "Value must be non-nil"
    private let msgTrue:    String = "Value must be true"
    private let msgFalse:   String = "Value must be false"
    private let msgEqual:   String = "Values must be equal"

    private let modelName = Constants.CoreData.modelName

    /// test_1: Oldest→Current with compatibility-aware expectation
    func test_1_migrateFromOldestToCurrent_succeedsOrIsAlreadyCompatible() throws {
        let bundles = candidateBundles()
        let steps   = discoverModelSteps(named: modelName, bundles: bundles)
        try XCTSkipIf(steps.count < 2, "Only one model version found — nothing to migrate")

        let legacyModel = steps.first!.model
        let storeURL    = temporaryStoreURL()

        try prepareDirectory(for: storeURL)
        _ = try createSQLiteStore(model: legacyModel, at: storeURL)

        let compatibleBefore = try isStore(storeURL, compatibleWith: loadCurrentModel(bundles)!)

        let didMigrate = try CoreDataMigrator.shared.migrateStore(
            modelName: modelName,
            storeURL: storeURL,
            allowInferredMappingAsFallback: true,
            bundles: bundles
        )

        XCTAssertEqual(didMigrate, !compatibleBefore, msgEqual)

        assertCurrentModelOpensStore(at: storeURL, bundles: bundles)
        cleanupSQLiteArtifacts(at: storeURL)
    }

    /// test_2: Pairwise migrate-or-compatible across all adjacent versions
    func test_2_migratePairwiseAcrossAllAdjacentVersions_awareOfCompatibility() throws {
        let bundles = candidateBundles()
        let steps   = discoverModelSteps(named: modelName, bundles: bundles)
        try XCTSkipIf(steps.count < 2, "Only one model version found — nothing to migrate")

        let currentModel = loadCurrentModel(bundles)!

        for i in 0..<(steps.count - 1) {
            let fromModel = steps[i].model
            let storeURL  = temporaryStoreURL(filename: "pair_\(i).sqlite")

            try prepareDirectory(for: storeURL)
            _ = try createSQLiteStore(model: fromModel, at: storeURL)

            let compatibleBefore = try isStore(storeURL, compatibleWith: currentModel)

            let didMigrate = try CoreDataMigrator.shared.migrateStore(
                modelName: modelName,
                storeURL: storeURL,
                allowInferredMappingAsFallback: true,
                bundles: bundles
            )

            XCTAssertEqual(didMigrate, !compatibleBefore, "Step \(i): migrate iff incompatible")

            assertCurrentModelOpensStore(at: storeURL, bundles: bundles)
            cleanupSQLiteArtifacts(at: storeURL)
        }
    }

    /// test_3: Current→Current is a strict no-op
    func test_3_migrationIsNoOp_whenStoreAlreadyCurrent() throws {
        let bundles = candidateBundles()
        let currentModel = loadCurrentModel(bundles)!

        let storeURL = temporaryStoreURL(filename: "noop.sqlite")
        try prepareDirectory(for: storeURL)
        _ = try createSQLiteStore(model: currentModel, at: storeURL)

        let didMigrate = try CoreDataMigrator.shared.migrateStore(
            modelName: modelName,
            storeURL: storeURL,
            allowInferredMappingAsFallback: true,
            bundles: bundles
        )
        XCTAssertFalse(didMigrate, msgFalse)

        assertCurrentModelOpensStore(at: storeURL, bundles: bundles)
        cleanupSQLiteArtifacts(at: storeURL)
    }

    private struct Step { let name: String; let url: URL; let model: NSManagedObjectModel }

    private func candidateBundles() -> [Bundle] {
        var arr: [Bundle] = []
        let frameworkBundle = Bundle(for: CoreDataMigrator.self)

        if let urlInFramework = frameworkBundle.url(forResource: "AltcraftResources", withExtension: "bundle"),
           let resInFramework = Bundle(url: urlInFramework) { arr.append(resInFramework) }

        if let urlInMain = Bundle.main.url(forResource: "AltcraftResources", withExtension: "bundle"),
           let resInMain = Bundle(url: urlInMain) { arr.append(resInMain) }

        #if SWIFT_PACKAGE
        arr.append(Bundle.module)
        #endif

        arr.append(frameworkBundle)
        arr.append(Bundle.main)
        return arr
    }

    private func loadCurrentModel(_ bundles: [Bundle]) -> NSManagedObjectModel? {
        for b in bundles {
            if let url = b.url(forResource: modelName, withExtension: "momd"),
               let m = NSManagedObjectModel(contentsOf: url) { return m }
            if let url = b.url(forResource: modelName, withExtension: "mom"),
               let m = NSManagedObjectModel(contentsOf: url) { return m }
        }
        return nil
    }

    private func discoverModelSteps(named: String, bundles: [Bundle]) -> [Step] {
        var steps: [Step] = []
        for b in bundles {
            if let momdURL = b.url(forResource: named, withExtension: "momd"),
               let contents = try? FileManager.default.contentsOfDirectory(at: momdURL, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "mom" {
                    if let m = NSManagedObjectModel(contentsOf: url) {
                        steps.append(Step(name: url.deletingPathExtension().lastPathComponent, url: url, model: m))
                    }
                }
            } else if let momURL = b.url(forResource: named, withExtension: "mom"),
                      let m = NSManagedObjectModel(contentsOf: momURL) {
                steps.append(Step(name: momURL.deletingPathExtension().lastPathComponent, url: momURL, model: m))
            }
        }
        steps.sort { $0.name < $1.name }
        return steps
    }

    private func isStore(_ storeURL: URL, compatibleWith model: NSManagedObjectModel) throws -> Bool {
        let md = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL, options: nil
        )
        return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: md)
    }

    @discardableResult
    private func createSQLiteStore(model: NSManagedObjectModel, at url: URL) throws -> NSPersistentContainer {
        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false
        desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let c = NSPersistentContainer(name: "Legacy", managedObjectModel: model)
        c.persistentStoreDescriptions = [desc]

        var loadError: Error?
        c.loadPersistentStores { _, e in loadError = e }
        if let e = loadError { throw e }

        c.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        c.viewContext.automaticallyMergesChangesFromParent = true

        if c.viewContext.hasChanges { try c.viewContext.save() }
        return c
    }

    private func assertCurrentModelOpensStore(at url: URL, bundles: [Bundle], file: StaticString = #file, line: UInt = #line) {
        guard let currentModel = loadCurrentModel(bundles) else {
            XCTFail("Current model not found: \(modelName)", file: file, line: line)
            return
        }

        let desc = NSPersistentStoreDescription(url: url)
        desc.type = NSSQLiteStoreType
        desc.shouldAddStoreAsynchronously = false

        let c = NSPersistentContainer(name: "Current", managedObjectModel: currentModel)
        c.persistentStoreDescriptions = [desc]

        let exp = expectation(description: "load current model store")
        var loadError: Error?
        c.loadPersistentStores { _, e in loadError = e; exp.fulfill() }
        wait(for: [exp], timeout: 5.0)

        XCTAssertNil(loadError, "Current model failed to open migrated store: \(String(describing: loadError))", file: file, line: line)
    }

    private func temporaryStoreURL(filename: String = UUID().uuidString + ".sqlite") -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("Altcraft_Migration_Tmp", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }

    private func prepareDirectory(for fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: fileURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        try? FileManager.default.removeItem(at: fileURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
    }

    private func cleanupSQLiteArtifacts(at fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: fileURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
        try? FileManager.default.removeItem(at: fileURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
    }
}
