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
 *  - test_3: getContext returns private queue context with correct configuration.
 *  - test_4: Two getContext calls produce distinct private contexts.
 *  - test_5: withBackgroundContext executes closure on background context.
 *  - test_6: Initializing CoreDataManager with custom appGroup does not crash and yields a container.
 *
 * Edge scenarios:
 *  - test_7: After container load, critical DB flag is not set (no error reported by load handler).
 *  - test_8: Context configuration includes correct merge policy and settings.
 *
 * Notes:
 *  - Tests avoid touching any specific NSManagedObject subclass or model entities.
 *    We verify container/contexts structurally to remain independent of the data model.
 *  - We do not rely on App Group being resolvable during tests; if store description
 *    cannot be built, NSPersistentContainer still loads a default in-app store.
 */
final class CoreDataManagerTests: IsolatedTestCase {

    // ---------- Messages ----------
    private let msgSameInstance   = "Must be the same shared instance"
    private let msgNonNil         = "Value must be non-nil"
    private let msgHasCoordinator = "Context must have a persistent store coordinator"
    private let msgPrivateQueue   = "Context must use private queue concurrency type"
    private let msgCalled         = "Completion must be called"
    private let msgDistinct       = "Contexts must be distinct"
    private let msgNoCritFlag     = "Critical DB flag must be false after normal load"
    private let msgCorrectMergePolicy = "Context must have correct merge policy"
    private let msgAutoMergeEnabled = "Context should automatically merge changes from parent"
    private let msgNoUndoManager   = "Context should not have undo manager"

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
        
        // Verify view context configuration
        XCTAssertTrue(ctx.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((ctx.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
    }

    // MARK: - test_3: getContext provides private queue context with correct configuration

    func test_3_getContext_returnsPrivateContext_withCorrectConfiguration() {
        let context = getContext()
        
        // Verify context type and configuration
        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
        XCTAssertNil(context.undoManager, msgNoUndoManager)
    }

    // MARK: - test_4: multiple calls produce distinct contexts

    func test_4_getContext_twice_producesDistinctPrivateContexts() {
        let context1 = getContext()
        let context2 = getContext()
        
        XCTAssertNotNil(context1, msgNonNil)
        XCTAssertNotNil(context2, msgNonNil)
        XCTAssertFalse(context1 === context2, msgDistinct)
        
        // Verify both have correct configuration
        XCTAssertEqual(context1.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertEqual(context2.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
    }

    // MARK: - test_5: withBackgroundContext executes closure on background context

    func test_5_withBackgroundContext_executesClosureOnBackgroundContext() {
        let expectation = self.expectation(description: "withBackgroundContext completion")
        
        withBackgroundContext { context in
            // Verify we're on a background context
            XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            XCTAssertTrue(context.automaticallyMergesChangesFromParent, self.msgAutoMergeEnabled)
            XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, self.msgCorrectMergePolicy)
            XCTAssertNil(context.undoManager, self.msgNoUndoManager)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: waitTimeout)
    }

    // MARK: - test_6: custom appGroup init does not crash

    func test_6_init_withCustomAppGroup_doesNotCrash_andCreatesContainer() {
        let mgr = CoreDataManager(appGroup: bogusGroup)
        let container = mgr.persistentContainer
        let ctx = container.viewContext
        XCTAssertNotNil(ctx, msgNonNil)
        XCTAssertNotNil(ctx.persistentStoreCoordinator, msgHasCoordinator)
        
        // Verify view context configuration
        XCTAssertTrue(ctx.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((ctx.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
    }

    // MARK: - test_7: crit DB flag remains false after normal load

    func test_7_afterLoad_critDBFlag_isFalse() {
        // CoreDataManager init sets crit flag in its load handler if error occurs.
        // Access the shared container to ensure load happened.
        _ = CoreDataManager.shared.persistentContainer
        
        // Use isolated UserDefaults for testing
        let userDefaults = StoredVariablesManager.shared
        XCTAssertFalse(userDefaults.getDbErrorStatus(), msgNoCritFlag)
    }

    // MARK: - test_8: context configuration verification

    func test_8_contextConfiguration_isCorrect() {
        let context = getContext()
        
        // Verify all configuration aspects
        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
        XCTAssertNil(context.undoManager, msgNoUndoManager)
        
        // Verify the context is associated with the persistent container
        XCTAssertNotNil(context.persistentStoreCoordinator, msgHasCoordinator)
    }
    
    /// test_9_multiple_withBackgroundContext_calls_workCorrectly
    func test_9_multiple_withBackgroundContext_calls_workCorrectly() {
        let expectation1 = self.expectation(description: "First background context")
        let expectation2 = self.expectation(description: "Second background context")
        
        // Используем thread-safe структуры
        let contextsQueue = DispatchQueue(label: "contexts.queue")
        var contexts: [NSManagedObjectContext] = []
        
        withBackgroundContext { context in
            contextsQueue.sync {
                contexts.append(context)
            }
            expectation1.fulfill()
        }
        
        withBackgroundContext { context in
            contextsQueue.sync {
                contexts.append(context)
            }
            expectation2.fulfill()
        }
        
        wait(for: [expectation1, expectation2], timeout: waitTimeout)
        
        // Проверяем после того как все завершилось
        contextsQueue.sync {
            XCTAssertEqual(contexts.count, 2, "Should have 2 contexts")
            XCTAssertFalse(contexts[0] === contexts[1], "Contexts should be distinct instances")
            
            // Verify both contexts have correct configuration
            for context in contexts {
                XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
                XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
                XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
            }
        }
    }
    
    // MARK: - test_10: isolated Core Data stack works correctly
    
    func test_10_isolatedCoreDataStack_worksCorrectly() {
        // Test that we can use the isolated Core Data stack
        let context = viewContext
        XCTAssertNotNil(context, "Isolated view context should be available")
        XCTAssertNotNil(context.persistentStoreCoordinator, "Isolated context should have coordinator")
        
        // Test background context creation
        let bgContext = newBGContext()
        XCTAssertEqual(bgContext.concurrencyType, .privateQueueConcurrencyType, "Background context should be private queue")
    }
}
