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
 */
final class CoreDataManagerTests: IsolatedTestCase {

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

    private let bogusGroup   = "group.com.altcraft.tests.nonexistent"
    private let waitTimeout  = 2.0

    /// test_1: Shared instance is a singleton (same object)
    func test_1_shared_isSingleton() {
        let a = CoreDataManager.shared
        let b = CoreDataManager.shared
        XCTAssertTrue(a === b, msgSameInstance)
    }

    /// test_2: Persistent container is loaded (has a viewContext with a coordinator)
    func test_2_container_isLoaded_hasCoordinator() {
        let container = CoreDataManager.shared.persistentContainer
        let ctx = container.viewContext
        XCTAssertNotNil(ctx, msgNonNil)
        XCTAssertNotNil(ctx.persistentStoreCoordinator, msgHasCoordinator)
        
        XCTAssertTrue(ctx.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((ctx.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
    }

    /// test_3: getContext returns private queue context with correct configuration
    func test_3_getContext_returnsPrivateContext_withCorrectConfiguration() {
        let context = getContext()
        
        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
        XCTAssertNil(context.undoManager, msgNoUndoManager)
    }

    /// test_4: Two getContext calls produce distinct private contexts
    func test_4_getContext_twice_producesDistinctPrivateContexts() {
        let context1 = getContext()
        let context2 = getContext()
        
        XCTAssertNotNil(context1, msgNonNil)
        XCTAssertNotNil(context2, msgNonNil)
        XCTAssertFalse(context1 === context2, msgDistinct)
        
        XCTAssertEqual(context1.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertEqual(context2.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
    }

    /// test_5: withBackgroundContext executes closure on background context
    func test_5_withBackgroundContext_executesClosureOnBackgroundContext() {
        let expectation = self.expectation(description: "withBackgroundContext completion")
        
        withBackgroundContext { context in
            XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            XCTAssertTrue(context.automaticallyMergesChangesFromParent, self.msgAutoMergeEnabled)
            XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, self.msgCorrectMergePolicy)
            XCTAssertNil(context.undoManager, self.msgNoUndoManager)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: waitTimeout)
    }

    /// test_6: Initializing CoreDataManager with custom appGroup does not crash and yields a container
    func test_6_init_withCustomAppGroup_doesNotCrash_andCreatesContainer() {
        let mgr = CoreDataManager(appGroup: bogusGroup)
        let container = mgr.persistentContainer
        let ctx = container.viewContext
        XCTAssertNotNil(ctx, msgNonNil)
        XCTAssertNotNil(ctx.persistentStoreCoordinator, msgHasCoordinator)
        
        XCTAssertTrue(ctx.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((ctx.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
    }

    /// test_7: After container load, critical DB flag is not set (no error reported by load handler)
    func test_7_afterLoad_critDBFlag_isFalse() {
        _ = CoreDataManager.shared.persistentContainer
        
        let userDefaults = StoredVariablesManager.shared
        XCTAssertFalse(userDefaults.getDbErrorStatus(), msgNoCritFlag)
    }

    /// test_8: Context configuration includes correct merge policy and settings
    func test_8_contextConfiguration_isCorrect() {
        let context = getContext()
        
        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
        XCTAssertNil(context.undoManager, msgNoUndoManager)
        
        XCTAssertNotNil(context.persistentStoreCoordinator, msgHasCoordinator)
    }
    
    /// test_9: Multiple withBackgroundContext calls work correctly and produce distinct contexts
    func test_9_multiple_withBackgroundContext_calls_workCorrectly() {
        let expectation1 = self.expectation(description: "First background context")
        let expectation2 = self.expectation(description: "Second background context")
        
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
        
        contextsQueue.sync {
            XCTAssertEqual(contexts.count, 2, "Should have 2 contexts")
            XCTAssertFalse(contexts[0] === contexts[1], "Contexts should be distinct instances")
            
            for context in contexts {
                XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
                XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
                XCTAssertEqual((context.mergePolicy as AnyObject).mergeType, .mergeByPropertyObjectTrumpMergePolicyType, msgCorrectMergePolicy)
            }
        }
    }
    
    /// test_10: Isolated Core Data stack works correctly with view and background contexts
    func test_10_isolatedCoreDataStack_worksCorrectly() {
        let context = viewContext
        XCTAssertNotNil(context, "Isolated view context should be available")
        XCTAssertNotNil(context.persistentStoreCoordinator, "Isolated context should have coordinator")
        
        let bgContext = newBGContext()
        XCTAssertEqual(bgContext.concurrencyType, .privateQueueConcurrencyType, "Background context should be private queue")
    }
}
