//
//  CoreDataMigratorContractTests.swift
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
* CoreDataMigratorContractTests
*
* Positive scenarios:
* - test_1: Default bundles collection → returns a non-empty bundle list.
* - test_2: Missing model lookup → returns nil for unknown model name.
*
* Negative scenarios:
* - test_3: Missing store URL → throws storeNotFound before any model work starts.
* - test_4: Existing file with missing model → throws modelNotFound.
* - test_5: Existing directory path with missing model → throws modelNotFound.
*
*/
final class CoreDataMigratorContractTests: IsolatedTestCase {

    /// test_1: default bundles collection returns a non-empty bundle list
    func test_1_default_bundles_collection() {
        let bundles = CoreDataMigrator.defaultBundles()

        XCTAssertFalse(bundles.isEmpty)
        XCTAssertTrue(
            bundles.contains(where: { $0.bundleURL == Bundle.main.bundleURL })
        )
        XCTAssertTrue(
            bundles.contains(where: { $0.bundleURL == Bundle(for: CoreDataMigrator.self).bundleURL })
        )
    }

    /// test_2: missing model lookup returns nil for unknown model name
    func test_2_missing_model_lookup() {
        let model = CoreDataMigrator.loadCurrentModel(
            named: "DefinitelyMissingModel_\(UUID().uuidString)",
            bundles: CoreDataMigrator.defaultBundles()
        )

        XCTAssertNil(model)
    }

    /// test_3: missing store URL throws storeNotFound before any model work starts
    func test_3_missing_store_url_throws_store_not_found() {
        let missingURL = temporaryURL(filename: UUID().uuidString + ".sqlite")

        XCTAssertFalse(FileManager.default.fileExists(atPath: missingURL.path))

        XCTAssertThrowsError(
            try CoreDataMigrator.shared.migrateStore(
                modelName: "AnyModelName",
                storeURL: missingURL,
                allowInferredMappingAsFallback: false,
                bundles: []
            )
        ) { error in
            guard case let HeavyMigrationError.storeNotFound(url) = error else {
                return XCTFail("Expected storeNotFound, got \(error)")
            }

            XCTAssertEqual(url, missingURL)
        }
    }

    /// test_4: existing file with missing model throws modelNotFound
    func test_4_existing_file_with_missing_model_throws_model_not_found() throws {
        let fileURL = temporaryURL(filename: UUID().uuidString + ".tmp")

        try prepareParentDirectory(for: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        FileManager.default.createFile(
            atPath: fileURL.path,
            contents: Data(),
            attributes: nil
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let missingModelName = "DefinitelyMissingModel_\(UUID().uuidString)"

        XCTAssertThrowsError(
            try CoreDataMigrator.shared.migrateStore(
                modelName: missingModelName,
                storeURL: fileURL,
                allowInferredMappingAsFallback: false,
                bundles: []
            )
        ) { error in
            guard case let HeavyMigrationError.modelNotFound(name) = error else {
                return XCTFail("Expected modelNotFound, got \(error)")
            }

            XCTAssertEqual(name, missingModelName)
        }
    }

    /// test_5: existing directory path with missing model throws modelNotFound
    func test_5_existing_directory_path_with_missing_model_throws_model_not_found() throws {
        let directoryURL = temporaryURL(filename: UUID().uuidString)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: directoryURL.path)
        )

        let missingModelName = "DefinitelyMissingModel_\(UUID().uuidString)"

        XCTAssertThrowsError(
            try CoreDataMigrator.shared.migrateStore(
                modelName: missingModelName,
                storeURL: directoryURL,
                allowInferredMappingAsFallback: false,
                bundles: []
            )
        ) { error in
            guard case let HeavyMigrationError.modelNotFound(name) = error else {
                return XCTFail("Expected modelNotFound, got \(error)")
            }

            XCTAssertEqual(name, missingModelName)
        }
    }

    private func temporaryURL(filename: String) -> URL {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return base
            .appendingPathComponent("Altcraft_Migrator_Contract_Tmp", isDirectory: true)
            .appendingPathComponent(filename, isDirectory: false)
    }

    private func prepareParentDirectory(for fileURL: URL) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
