//
//  CoreDataManagerTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * CoreDataManagerTests
 *
 * Positive scenarios:
 *  - test_1: Shared instance is a singleton (same object).
 *  - test_2: Persistent container is loaded (has a viewContext with a coordinator).
 *  - test_3: getContext calls completion on a private queue context.
 *  - test_4: Two getContext calls produce distinct private contexts.
 *  - test_5: Initializing CoreDataManager with a custom (even bogus) appGroup does not crash and yields a container.
 *
 * Edge scenarios:
 *  - test_6: After container load, critical DB flag is not set (no error reported by load handler).
 *
 * Notes:
 *  - Tests avoid touching any specific NSManagedObject subclass or model entities.
 *    We verify container/contexts structurally to remain independent of the data model.
 *  - We do not rely on App Group being resolvable during tests; if store description
 *    cannot be built, NSPersistentContainer still loads a default in-app store.
 */
final class CoreDataManagerTests: XCTestCase {

    // ---------- Messages ----------
    private let msgSameInstance   = "Must be the same shared instance"
    private let msgNonNil         = "Value must be non-nil"
    private let msgHasCoordinator = "Context must have a persistent store coordinator"
    private let msgPrivateQueue   = "Context must use private queue concurrency type"
    private let msgCalled         = "Completion must be called"
    private let msgDistinct       = "Contexts must be distinct"
    private let msgNoCritFlag     = "Critical DB flag must be false after normal load"

    // ---------- Constants ----------
    private let bogusGroup   = "group.com.altcraft.tests.nonexistent"
    private let waitTimeout  = 2.0

    // MARK: - test_1: singleton behavior

    func test_1_shared_isSingleton() {
        let a = CoreDataManager.shared
        let b = CoreDataManager.shared
        XCTAssertTrue(a === b, msgSameInstance)
    }

    // MARK: - test_2: container is loaded

    func test_2_container_isLoaded_hasCoordinator() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.viewContext
        XCTAssertNotNil(ctx, msgNonNil)
        XCTAssertNotNil(ctx.persistentStoreCoordinator, msgHasCoordinator)
    }

    // MARK: - test_3: getContext provides private queue context and calls completion

    func test_3_getContext_providesPrivateContext_andCallsCompletion() {
        let exp = expectation(description: "getContext completion")
        var received: NSManagedObjectContext?

        getContext { ctx in
            received = ctx
            // The block given to performBackgroundTask is executed on a private queue.
            XCTAssertEqual(ctx.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            exp.fulfill()
        }

        wait(for: [exp], timeout: waitTimeout)
        XCTAssertNotNil(received, msgCalled)
    }

    // MARK: - test_4: multiple calls produce distinct contexts

    func test_4_getContext_twice_producesDistinctPrivateContexts() {
        let exp = expectation(description: "two contexts")
        exp.expectedFulfillmentCount = 2

        var c1: NSManagedObjectContext?
        var c2: NSManagedObjectContext?

        getContext { ctx in
            c1 = ctx
            XCTAssertEqual(ctx.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            exp.fulfill()
        }
        getContext { ctx in
            c2 = ctx
            XCTAssertEqual(ctx.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            exp.fulfill()
        }

        wait(for: [exp], timeout: waitTimeout)
        XCTAssertNotNil(c1, msgNonNil)
        XCTAssertNotNil(c2, msgNonNil)
        if let c1, let c2 {
            XCTAssertFalse(c1 === c2, msgDistinct)
        }
    }

    // MARK: - test_5: custom appGroup init does not crash

    func test_5_init_withCustomAppGroup_doesNotCrash_andCreatesContainer() {
        let mgr = CoreDataManager(appGroup: bogusGroup)
        let container = mgr.persistentContainer
        let ctx = container.viewContext
        XCTAssertNotNil(ctx, msgNonNil)
        XCTAssertNotNil(ctx.persistentStoreCoordinator, msgHasCoordinator)
    }

    // MARK: - test_6: crit DB flag remains false after normal load

    func test_6_afterLoad_critDBFlag_isFalse() {
        // CoreDataManager init sets crit flag in its load handler if error occurs.
        // Access the shared container to ensure load happened.
        _ = CoreDataManager.shared.persistentContainer
        XCTAssertFalse(StoredVariablesManager.shared.getDbErrorStatus(), msgNoCritFlag)
    }
}

