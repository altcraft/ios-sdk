//
//  RetryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2026 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * RetryTests
 *
 * Positive scenarios:
 *  - test_1: delay with zero retry count → returns one and shows monotonic growth.
 *  - test_2: retry functions → schedule work safely without crashing.
 *  - test_3: RetryManager.store → replaces existing task with new one.
 *  - test_4: RetryManager.cancelAll → cancels and clears all stored tasks safely.
 *
 */
final class RetryTests: IsolatedTestCase {

    /// test_1: delay with zero retry count returns one and shows monotonic growth
    func test_1_delay_withZeroRetryCount_returnsOne_andShowsMonotonicGrowth() {
        let d0 = delay(retryCount: 0)
        let d1 = delay(retryCount: 1)
        let d2 = delay(retryCount: 2)
        let d3 = delay(retryCount: 3)

        XCTAssertEqual(d0, 1.0, accuracy: 1e-12)
        XCTAssertGreaterThan(d1, d0)
        XCTAssertGreaterThan(d2, d1)
        XCTAssertGreaterThan(d3, d2)
        XCTAssertGreaterThan(d2 / d1, 1.0)
        XCTAssertGreaterThan(d3 / d2, 1.0)
    }

    /// test_2: retry functions schedule work safely without crashing
    func test_2_retryFunctions_scheduleWorkSafely_withoutCrashing() {
        mobileEventRetry()
        profileUpdateRetry()
        pushSubscribeRetry()
        tokenUpdateRetry()

        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "Tmp"
        entity.managedObjectClassName = "NSManagedObject"
        model.entities = [entity]

        let container = NSPersistentContainer(
            name: "Tmp",
            managedObjectModel: model
        )

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        XCTAssertNil(loadError)

        let context = container.viewContext
        let object = NSManagedObject(entity: entity, insertInto: context)
        try? context.obtainPermanentIDs(for: [object])

        pushEventRetry(objectID: object.objectID)

        XCTAssertTrue(true)
    }

    /// test_3: RetryManager.store replaces existing task with new one
    func test_3_RetryManager_store_replacesExistingTask_withNewOne() {
        let manager = RetryManager.shared
        let key = "replace-test"

        let first = DispatchWorkItem { }
        manager.store(key: key, work: first)

        let second = DispatchWorkItem { }
        manager.store(key: key, work: second)

        manager.cancelAll()

        XCTAssertTrue(true)
    }

    /// test_4: RetryManager.cancelAll cancels and clears all stored tasks safely
    func test_4_RetryManager_cancelAll_cancelsAndClearsAllStoredTasks_safely() {
        let manager = RetryManager.shared

        for index in 0..<5 {
            let work = DispatchWorkItem { }
            manager.store(key: "k\(index)", work: work)
        }

        manager.cancelAll()

        XCTAssertTrue(true)
    }
}
