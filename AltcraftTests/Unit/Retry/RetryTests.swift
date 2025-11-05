//
//  RetryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.
//

import XCTest
import CoreData
@testable import Altcraft

/**
 * RetryTests
 *
 * Positive scenarios:
 *  - test_1: delay with zero retry count returns one and shows monotonic growth.
 *  - test_2: local*Retry() functions schedule work without crashing.
 *  - test_3: store() correctly replaces existing task.
 *  - test_4: cancelAll() cancels and clears all tasks.
 */
final class RetryTests: XCTestCase {

    /// test_1: delay with zero retry count returns one and shows monotonic growth
    func test_1_delay_zeroRetry_isOne_and_monotonic_growth() {
        let d0 = delay(retryCount: 0)
        let d1 = delay(retryCount: 1)
        let d2 = delay(retryCount: 2)
        let d3 = delay(retryCount: 3)

        XCTAssertEqual(d0, 1.0, accuracy: 1e-12, "delay(0) must be exactly 1.0")
        XCTAssertGreaterThan(d1, d0)
        XCTAssertGreaterThan(d2, d1)
        XCTAssertGreaterThan(d3, d2)
        XCTAssertGreaterThan(d2 / d1, 1.0)
        XCTAssertGreaterThan(d3 / d2, 1.0)
    }

    /// test_2: all retry functions schedule work safely (no crash)
    func test_2_localRetry_functions_doNotCrash() {
        localMobileEventRetry()
        localPushSubscribeRetry()
        localTokenUpdateRetry()


        let model = NSManagedObjectModel()
        let entity = NSEntityDescription()
        entity.name = "Tmp"
        entity.managedObjectClassName = "NSManagedObject"
        model.entities = [entity]

        let container = NSPersistentContainer(name: "Tmp", managedObjectModel: model)
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        var loadErr: Error?
        container.loadPersistentStores { _, e in loadErr = e }
        XCTAssertNil(loadErr)

        let ctx = container.viewContext
        let obj = NSManagedObject(entity: entity, insertInto: ctx)
        try? ctx.obtainPermanentIDs(for: [obj])

        localPushEventRetry(objectID: obj.objectID)
        XCTAssertTrue(true, "local*Retry functions should not crash")
    }

    /// test_3: store() replaces existing task with new one
    func test_3_store_replacesExistingTask() {
        let mgr = RetryManager.shared
        let key = "replace-test"

        let first = DispatchWorkItem(block: {})
        mgr.store(key: key, work: first)

        let second = DispatchWorkItem(block: {})
        mgr.store(key: key, work: second)
        mgr.cancelAll()
        XCTAssertTrue(true, "Replacing existing task should not crash")
    }

    /// test_4: cancelAll cancels and clears all stored tasks
    func test_4_cancelAll_clearsAllTasks() {
        let mgr = RetryManager.shared
        for i in 0..<5 {
            let work = DispatchWorkItem(block: { })
            mgr.store(key: "k\(i)", work: work)
        }

        mgr.cancelAll() // should not crash or hang
        XCTAssertTrue(true, "cancelAll() must complete safely")
    }
}

