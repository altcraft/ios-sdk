//
//  ClearingDbTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * ClearingDbTests (iOS 13 compatible)
 *
 * Positive scenarios:
 *  - test_2_deleteEntity_existingObjects_deletesAll_andCallsCompletionOnMain:
 *      deleteEntity removes all objects of an existing entity and calls completion on main thread.
 *  - test_3_deleteAllEntitiesFromDb_deletesPredefinedEntities_andCallsCompletionOnMain:
 *      deleteAllEntitiesFromDb clears all predefined entities and reports true.
 *
 * Edge scenarios:
 *  - test_1_deleteEntity_unknownEntity_returnsFalse_andCallsCompletionOnMain:
 *      deleteEntity with an unknown entity name returns false and calls completion on main thread.
 *
 * Notes:
 *  - Uses CoreDataManager.shared.persistentContainer from production (no seams).
 *  - Avoids throwing `performAndWait` (iOS 15+) by capturing errors manually.
 *  - String literals and numbers extracted into constants for clarity.
 */
final class ClearingDbTests: XCTestCase {

    // MARK: - Constants

    private let unknownEntityName = "__Unknown__Entity__For__Test__"
    private let timeoutShort: TimeInterval = 2.0
    private let timeoutLong:  TimeInterval = 3.0
    private let seedCountSmall = 3
    private let seedCountBulk  = 2

    private var predefinedEntities: [String] {
        [
            Constants.EntityNames.configEntityName,
            Constants.EntityNames.subscribeEntityName,
            Constants.EntityNames.pushEventEntityName
        ]
    }

    // MARK: - Helpers

    /// Returns true if the Core Data model contains the given entity name.
    private func modelHasEntity(named entityName: String) -> Bool {
        let model = CoreDataManager.shared.persistentContainer.managedObjectModel
        return model.entitiesByName[entityName] != nil
    }

    /// Fetches count for an entity (thread-safe; returns nil if fetch fails).
    private func fetchCount(entityName: String) -> Int? {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.viewContext
        var result: Int?
        ctx.performAndWait {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetch.includesSubentities = true
            do {
                result = try ctx.count(for: fetch)
            } catch {
                result = nil
            }
        }
        return result
    }

    /// Inserts N empty NSManagedObject instances for the given entity into a background context and saves.
    /// iOS 13-compatible: uses non-throwing performAndWait and captures errors manually.
    private func seed(entityName: String, count: Int) throws {
        let container = CoreDataManager.shared.persistentContainer
        let bg = container.newBackgroundContext()

        var thrownError: Error?
        bg.performAndWait {
            guard let _ = NSEntityDescription.entity(forEntityName: entityName, in: bg) else {
                thrownError = NSError(
                    domain: "ClearingDbTests",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Entity not found: \(entityName)"]
                )
                return
            }
            for _ in 0..<count {
                _ = NSEntityDescription.insertNewObject(forEntityName: entityName, into: bg)
            }
            if bg.hasChanges {
                do {
                    try bg.save()
                } catch {
                    thrownError = error
                }
            }
        }
        if let e = thrownError { throw e }
    }

    // MARK: - Edge case: unknown entity

    /// test_1_deleteEntity_unknownEntity_returnsFalse_andCallsCompletionOnMain
    func test_1_deleteEntity_unknownEntity_returnsFalse_andCallsCompletionOnMain() {
        let exp = expectation(description: "completion called for unknown entity")

        ClearingDb.shared.deleteEntity(entityName: unknownEntityName) { success in
            XCTAssertTrue(Thread.isMainThread, "Completion must be called on main thread")
            XCTAssertFalse(success, "Expected false for unknown entity name")
            exp.fulfill()
        }

        waitForExpectations(timeout: timeoutShort)
    }

    // MARK: - Single-entity deletion

    /// test_2_deleteEntity_existingObjects_deletesAll_andCallsCompletionOnMain
    func test_2_deleteEntity_existingObjects_deletesAll_andCallsCompletionOnMain() throws {
        // Pick the first existing entity from the predefined list
        guard let entityName = predefinedEntities.first(where: { modelHasEntity(named: $0) }) else {
            throw XCTSkip("No predefined entities exist in the Core Data model for this test target")
        }

        // Seed with several objects
        try seed(entityName: entityName, count: seedCountSmall)

        let before = fetchCount(entityName: entityName)
        XCTAssertNotNil(before, "Count fetch should succeed before deletion for \(entityName)")
        XCTAssertGreaterThan(before ?? 0, 0, "There should be objects to delete in \(entityName)")

        let exp = expectation(description: "delete completion main for \(entityName)")
        ClearingDb.shared.deleteEntity(entityName: entityName) { success in
            XCTAssertTrue(Thread.isMainThread, "Completion must be called on main thread")
            XCTAssertTrue(success, "Expected true for successful deletion of \(entityName)")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutShort)

        let after = fetchCount(entityName: entityName)
        XCTAssertNotNil(after, "Count fetch should succeed after deletion for \(entityName)")
        XCTAssertEqual(after, 0, "All objects must be deleted for \(entityName)")
    }

    // MARK: - Bulk deletion

    /// test_3_deleteAllEntitiesFromDb_deletesPredefinedEntities_andCallsCompletionOnMain
    func test_3_deleteAllEntitiesFromDb_deletesPredefinedEntities_andCallsCompletionOnMain() throws {
        let existing = predefinedEntities.filter { modelHasEntity(named: $0) }
        guard !existing.isEmpty else {
            throw XCTSkip("None of predefined entities exist in the Core Data model for this test target")
        }

        // Seed each existing entity
        for entityName in existing {
            try seed(entityName: entityName, count: seedCountBulk)
            let c = fetchCount(entityName: entityName)
            XCTAssertNotNil(c, "Pre-check count should succeed for \(entityName)")
            XCTAssertGreaterThan(c ?? 0, 0, "Should have pre-seeded objects in \(entityName)")
        }

        let exp = expectation(description: "bulk delete completion main")
        ClearingDb.shared.deleteAllEntitiesFromDb { success in
            XCTAssertTrue(Thread.isMainThread, "Completion must be called on main thread")
            XCTAssertTrue(success, "Expected overall success when all deletes succeed")
            exp.fulfill()
        }
        waitForExpectations(timeout: timeoutLong)

        for entityName in existing {
            let c = fetchCount(entityName: entityName)
            XCTAssertNotNil(c, "Post-check count should succeed for \(entityName)")
            XCTAssertEqual(c, 0, "Entity \(entityName) should be empty after bulk deletion")
        }
    }
}

