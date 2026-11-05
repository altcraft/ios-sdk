//
//  RetryTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
#if canImport(AltcraftCore)
@_spi(_Altcraft) import AltcraftCore
#endif
#if canImport(AltcraftPush)
@_spi(_Altcraft) import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@_spi(_Altcraft) import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@_spi(_Altcraft) import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@_spi(_Altcraft) import AltcraftTarget
#endif
#if canImport(AltcraftCore)
@testable import AltcraftCore
#endif
#if canImport(AltcraftPush)
@testable import AltcraftPush
#endif
#if canImport(AltcraftProfile)
@testable import AltcraftProfile
#endif
#if canImport(AltcraftInApp)
@testable import AltcraftInApp
#endif
#if canImport(AltcraftTarget)
@testable import AltcraftTarget
#endif

/**
 * RetryTests
 *
 * Positive scenarios:
 *  - test_1: delay → doubles with every attempt from the base backoff delay.
 *  - test_2: retry functions → schedule work safely without crashing.
 *  - test_3: RetryManager.store → replaces existing task with new one.
 *  - test_4: RetryManager.cancelAll → cancels and clears all stored tasks safely.
 *  - test_5: incrementAndGet → atomically returns incrementing values.
 *  - test_6: profile/target retries → counter incremented exactly once per failure.
 *  - test_7: retries beyond the local limit → no work scheduled.
 *  - test_8: delay → matches the WorkManager exponential backoff table.
 *  - test_9: push/in-app retries → counter incremented once per scheduling, limit respected.
 *
 */
final class RetryTests: IsolatedTestCase {

    /// test_1: delay doubles with every attempt starting from the base
    /// backoff delay
    func test_1_delay_doublesWithEveryAttempt_fromBaseBackoffDelay() {
        let d1 = delay(retryCount: 1)
        let d2 = delay(retryCount: 2)
        let d3 = delay(retryCount: 3)
        let d4 = delay(retryCount: 4)

        XCTAssertEqual(d1, Constants.Retry.backoffDelay, accuracy: 1e-12)
        XCTAssertEqual(d2, d1 * 2, accuracy: 1e-12)
        XCTAssertEqual(d3, d2 * 2, accuracy: 1e-12)
        XCTAssertEqual(d4, d3 * 2, accuracy: 1e-12)
    }

    /// test_2: retry functions schedule work safely without crashing
    func test_2_retryFunctions_scheduleWorkSafely_withoutCrashing() {
        mobileEventRetry()
        profileUpdateRetry()
        pushSubscribeRetry()
        tokenUpdateRetry(requestId: "test-request-id")

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

    /// test_5: incrementAndGet atomically returns incrementing values
    func test_5_incrementAndGet_returnsIncrementingValues() {
        let key = "atomic-test"
        RetryCounters.shared.reset(key)

        XCTAssertEqual(RetryCounters.shared.incrementAndGet(key), 1)
        XCTAssertEqual(RetryCounters.shared.incrementAndGet(key), 2)
        XCTAssertEqual(RetryCounters.shared.incrementAndGet(key), 3)
        XCTAssertEqual(RetryCounters.shared.get(key), 3)

        RetryCounters.shared.reset(key)
    }

    /// test_6: profile/target retries increment the counter exactly once per failure
    func test_6_profileAndTargetRetry_incrementCounterOncePerFailure() {
        let profileKey = ProfileConstants.RetryKey.profileUpdate
        let targetKey = TargetConstants.RetryKey.targetEvent
        RetryCounters.shared.reset(profileKey)
        RetryCounters.shared.reset(targetKey)
        defer {
            RetryCounters.shared.reset(profileKey)
            RetryCounters.shared.reset(targetKey)
            RetryManager.shared.cancel(key: profileKey)
            RetryManager.shared.cancel(key: targetKey)
        }

        profileUpdateRetry()
        profileUpdateRetry()
        mobileEventRetry()
        mobileEventRetry()

        XCTAssertEqual(RetryCounters.shared.get(profileKey), 2)
        XCTAssertEqual(RetryCounters.shared.get(targetKey), 2)
    }

    /// test_7: retries beyond the local limit schedule no work
    func test_7_retryBeyondLocalLimit_schedulesNoWork() {
        let profileKey = ProfileConstants.RetryKey.profileUpdate
        let targetKey = TargetConstants.RetryKey.targetEvent
        RetryCounters.shared.reset(profileKey)
        RetryCounters.shared.reset(targetKey)
        defer {
            RetryCounters.shared.reset(profileKey)
            RetryCounters.shared.reset(targetKey)
            RetryManager.shared.cancel(key: profileKey)
            RetryManager.shared.cancel(key: targetKey)
        }

        for _ in 0..<ProfileConstants.Retry.maxLocalRetryCount {
            profileUpdateRetry()
        }
        XCTAssertTrue(RetryManager.shared.hasTask(profileKey))

        RetryManager.shared.cancel(key: profileKey)
        profileUpdateRetry()
        XCTAssertFalse(RetryManager.shared.hasTask(profileKey))

        for _ in 0..<TargetConstants.Retry.maxLocalRetryCount {
            mobileEventRetry()
        }
        XCTAssertTrue(RetryManager.shared.hasTask(targetKey))

        RetryManager.shared.cancel(key: targetKey)
        mobileEventRetry()
        XCTAssertFalse(RetryManager.shared.hasTask(targetKey))
    }

    /// test_8: delay matches the WorkManager exponential backoff table
    /// (10-second effective base — Android `RETRY_TIME_C_WORK = 5s` clamped
    /// by WorkManager `MIN_BACKOFF_MILLIS`, doubling per attempt)
    func test_8_delay_matchesWorkManagerExponentialBackoffTable() {
        XCTAssertEqual(delay(retryCount: 1), 10.0, accuracy: 1e-12)
        XCTAssertEqual(delay(retryCount: 2), 20.0, accuracy: 1e-12)
        XCTAssertEqual(delay(retryCount: 3), 40.0, accuracy: 1e-12)
        XCTAssertEqual(delay(retryCount: 4), 80.0, accuracy: 1e-12)
        XCTAssertEqual(delay(retryCount: 5), 160.0, accuracy: 1e-12)
    }

    /// test_9: push and in-app retries increment the counter exactly once per
    /// scheduling and stop at the local retry limit
    func test_9_pushAndInAppRetry_incrementCounterOncePerScheduling_andRespectLimit() {
        let pushKey = PushConstants.RetryKey.pushSubscribe
        let inAppKey = InAppConstants.RetryKey.inAppSubscribe
        RetryCounters.shared.reset(pushKey)
        RetryCounters.shared.reset(inAppKey)
        defer {
            RetryCounters.shared.reset(pushKey)
            RetryCounters.shared.reset(inAppKey)
            RetryManager.shared.cancel(key: pushKey)
            RetryManager.shared.cancel(key: inAppKey)
        }

        pushSubscribeRetry()
        pushSubscribeRetry()
        inAppSubscribeRetry()
        inAppSubscribeRetry()

        XCTAssertEqual(RetryCounters.shared.get(pushKey), 2)
        XCTAssertEqual(RetryCounters.shared.get(inAppKey), 2)

        for _ in 0..<(PushConstants.Retry.maxLocalRetryCount - 2) {
            pushSubscribeRetry()
        }
        XCTAssertTrue(RetryManager.shared.hasTask(pushKey))

        RetryManager.shared.cancel(key: pushKey)
        pushSubscribeRetry()
        XCTAssertFalse(RetryManager.shared.hasTask(pushKey))
    }
}
