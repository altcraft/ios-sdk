//
//  CoreDataManagerTests.swift
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
* CoreDataManagerTests
*
* Positive scenarios:
* - test_1: Shared instance is a singleton.
* - test_2: Persistent container is loaded and viewContext has coordinator.
* - test_3: getContext returns private queue context with correct configuration.
* - test_4: Two getContext calls produce distinct private contexts.
* - test_5: performBackgroundTask executes closure on background context.
* - test_6: Initializing CoreDataManager with custom appGroup does not crash and yields a container.
* - test_7: After container load critical DB flag is false.
* - test_8: Context configuration includes correct merge policy and settings.
* - test_9: Multiple performBackgroundTask calls work correctly and produce distinct contexts.
* - test_10: Isolated Core Data stack works correctly with view and background contexts.
*
*/
final class CoreDataManagerTests: IsolatedTestCase {

    private let msgSameInstance = "Must be the same shared instance"
    private let msgNonNil = "Value must be non-nil"
    private let msgHasCoordinator = "Context must have a persistent store coordinator"
    private let msgPrivateQueue = "Context must use private queue concurrency type"
    private let msgDistinct = "Contexts must be distinct"
    private let msgNoCritFlag = "Critical DB flag must be false after normal load"
    private let msgCorrectMergePolicy = "Context must have correct merge policy"
    private let msgAutoMergeEnabled = "Context should automatically merge changes from parent"
    private let msgNoUndoManager = "Context should not have undo manager"

    private let bogusGroup = "group.com.altcraft.tests.nonexistent"

    /// test_1: Shared instance is a singleton
    func test_1_shared_instance_is_a_singleton() {
        let first = CoreDataManager.shared
        let second = CoreDataManager.shared

        XCTAssertTrue(first === second, msgSameInstance)
    }

    /// test_2: Persistent container is loaded and viewContext has coordinator
    func test_2_persistent_container_is_loaded_and_view_context_has_coordinator() {
        let container = CoreDataManager.shared.persistentContainer
        let context = container.viewContext

        XCTAssertNotNil(context, msgNonNil)
        XCTAssertNotNil(context.persistentStoreCoordinator, msgHasCoordinator)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual(
            (context.mergePolicy as AnyObject).mergeType,
            .mergeByPropertyObjectTrumpMergePolicyType,
            msgCorrectMergePolicy
        )
    }

    /// test_3: getContext returns private queue context with correct configuration
    func test_3_get_context_returns_private_queue_context_with_correct_configuration() {
        let context = CoreDataManager.shared.getContext()

        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual(
            (context.mergePolicy as AnyObject).mergeType,
            .mergeByPropertyObjectTrumpMergePolicyType,
            msgCorrectMergePolicy
        )
        XCTAssertNil(context.undoManager, msgNoUndoManager)
    }

    /// test_4: Two getContext calls produce distinct private contexts
    func test_4_two_get_context_calls_produce_distinct_private_contexts() {
        let firstContext = CoreDataManager.shared.getContext()
        let secondContext = CoreDataManager.shared.getContext()

        XCTAssertNotNil(firstContext, msgNonNil)
        XCTAssertNotNil(secondContext, msgNonNil)
        XCTAssertFalse(firstContext === secondContext, msgDistinct)
        XCTAssertEqual(firstContext.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertEqual(secondContext.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
    }

    /// test_5: performBackgroundTask executes closure on background context
    func test_5_perform_background_task_executes_closure_on_background_context() async throws {
        let result = try await CoreDataManager.shared.performBackgroundTask { context in
            XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, self.msgPrivateQueue)
            XCTAssertTrue(context.automaticallyMergesChangesFromParent, self.msgAutoMergeEnabled)
            XCTAssertEqual(
                (context.mergePolicy as AnyObject).mergeType,
                .mergeByPropertyObjectTrumpMergePolicyType,
                self.msgCorrectMergePolicy
            )
            XCTAssertNil(context.undoManager, self.msgNoUndoManager)
            return true
        }

        XCTAssertTrue(result)
    }

    /// test_6: Initializing CoreDataManager with custom appGroup does not crash and yields a container
    func test_6_initializing_with_custom_app_group_does_not_crash_and_yields_a_container() {
        let manager = CoreDataManager(appGroup: bogusGroup)
        let container = manager.persistentContainer
        let context = container.viewContext

        XCTAssertNotNil(context, msgNonNil)
        XCTAssertNotNil(context.persistentStoreCoordinator, msgHasCoordinator)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual(
            (context.mergePolicy as AnyObject).mergeType,
            .mergeByPropertyObjectTrumpMergePolicyType,
            msgCorrectMergePolicy
        )
    }

    /// test_7: After container load critical DB flag is false
    func test_7_after_container_load_critical_db_flag_is_false() {
        _ = CoreDataManager.shared.persistentContainer

        let userDefaults = StoredVariablesManager.shared
        XCTAssertFalse(userDefaults.getDbErrorStatus(), msgNoCritFlag)
    }

    /// test_8: Context configuration includes correct merge policy and settings
    func test_8_context_configuration_includes_correct_merge_policy_and_settings() {
        let context = CoreDataManager.shared.getContext()

        XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
        XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
        XCTAssertEqual(
            (context.mergePolicy as AnyObject).mergeType,
            .mergeByPropertyObjectTrumpMergePolicyType,
            msgCorrectMergePolicy
        )
        XCTAssertNil(context.undoManager, msgNoUndoManager)
        XCTAssertNotNil(context.persistentStoreCoordinator, msgHasCoordinator)
    }

    /// test_9: Multiple performBackgroundTask calls work correctly and produce distinct contexts
    func test_9_multiple_perform_background_task_calls_work_correctly_and_produce_distinct_contexts() async throws {
        let firstContext = try await CoreDataManager.shared.performBackgroundTask { context in
            context
        }

        let secondContext = try await CoreDataManager.shared.performBackgroundTask { context in
            context
        }

        XCTAssertFalse(firstContext === secondContext, msgDistinct)

        for context in [firstContext, secondContext] {
            XCTAssertEqual(context.concurrencyType, .privateQueueConcurrencyType, msgPrivateQueue)
            XCTAssertTrue(context.automaticallyMergesChangesFromParent, msgAutoMergeEnabled)
            XCTAssertEqual(
                (context.mergePolicy as AnyObject).mergeType,
                .mergeByPropertyObjectTrumpMergePolicyType,
                msgCorrectMergePolicy
            )
            XCTAssertNil(context.undoManager, msgNoUndoManager)
        }
    }

    /// test_10: Isolated Core Data stack works correctly with view and background contexts
    func test_10_isolated_core_data_stack_works_correctly_with_view_and_background_contexts() {
        let context = viewContext
        XCTAssertNotNil(context, "Isolated view context should be available")
        XCTAssertNotNil(context.persistentStoreCoordinator, "Isolated context should have coordinator")

        let backgroundContext = newBGContext()
        XCTAssertEqual(
            backgroundContext.concurrencyType,
            .privateQueueConcurrencyType,
            "Background context should be private queue"
        )
    }
}
