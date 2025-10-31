//
//  RetryTests.swift
//  AltcraftTests
//
//  Created by Andrey Pogodin.
//
//  © 2025 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import Altcraft

/**
 * RetryTests
 *
 * Positive scenarios:
 *  - test_1: delay with zero retry count returns one and shows monotonic growth.
 *  - test_2: requestRetry with unknown code does not crash.
 *  - test_3: requestRetry push event with valid objectID does not crash.
 *  - test_4: requestRetry with other codes does not crash without event.
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

    /// test_2: requestRetry with unknown code does not crash
    func test_2_requestRetry_unknownCode_doesNotCrash() {
        requestRetry(request: "__unknown__")
        XCTAssertTrue(true)
    }

    /// test_3: requestRetry push event with valid objectID does not crash
    func test_3_requestRetry_pushEvent_withValidObjectID_doesNotCrash() {
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

        requestRetry(request: Constants.FunctionsCode.PE, event: obj.objectID)
        XCTAssertTrue(true)
    }

    /// test_4: requestRetry with other codes does not crash without event
    func test_4_requestRetry_otherCodes_doesNotCrash_withoutEvent() {
        requestRetry(request: Constants.FunctionsCode.SS)
        requestRetry(request: Constants.FunctionsCode.SU)
        requestRetry(request: Constants.FunctionsCode.ME)
        XCTAssertTrue(true)
    }
}
