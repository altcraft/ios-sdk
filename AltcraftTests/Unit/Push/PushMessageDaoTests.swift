//
//  PushMessageDaoTests.swift
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
 * PushMessageDaoTests
 *
 * Positive scenarios:
 * - test_1: the first delivery claim of a UID returns true.
 * - test_2: different UIDs are each claimed for delivery.
 * - test_3: the first open claim returns true, also when a delivery record
 *   already exists.
 * - test_4: a delivery claim after an open-created record returns true
 *   (the delivery event was never sent).
 * - test_5: only the latest 100 records are kept; a trimmed-out UID is
 *   claimed again while the newest stays recorded.
 *
 * Negative scenarios:
 * - test_6: repeated delivery and open claims return false.
 */
final class PushMessageDaoTests: IsolatedTestCase {

    override class var useSDKCoreData: Bool { true }

    override class var sdkManagerContainer: NSPersistentContainer? {
        pushDatabase.persistentContainer
    }

    private let entityName = PushConstants.EntityNames.pushMessageEntity

    override func setUpWithError() throws {
        try super.setUpWithError()
        sdkWipe([entityName])
    }

    override func tearDownWithError() throws {
        sdkWipe([entityName])
        StoredVariablesManager.shared.setCritDB(value: false)
        try super.tearDownWithError()
    }

    // MARK: - Positive

    /// - test_1: The first delivery claim of a UID returns true.
    func test_1_first_delivery_claim_returns_true() async throws {
        let shouldSend = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-1")
        XCTAssertTrue(shouldSend)
    }

    /// - test_2: Different UIDs are each claimed for delivery.
    func test_2_different_uids_are_each_claimed() async throws {
        for i in 1...3 {
            let shouldSend = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-\(i)")
            XCTAssertTrue(shouldSend, "uid-\(i)")
        }
        XCTAssertEqual(sdkCount(entityName: entityName), 3)
    }

    /// - test_3: The first open claim returns true, also when a delivery
    ///   record already exists; the second open claim returns false.
    func test_3_open_claim_once_per_uid() async throws {
        let delivery = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-1")
        XCTAssertTrue(delivery)

        let firstOpen = await PushMessageDAO.shouldSendOpenEvent(uid: "uid-1")
        XCTAssertTrue(firstOpen)

        let secondOpen = await PushMessageDAO.shouldSendOpenEvent(uid: "uid-1")
        XCTAssertFalse(secondOpen)

        XCTAssertEqual(sdkCount(entityName: entityName), 1)
    }

    /// - test_4: A delivery claim after an open-created record returns true.
    func test_4_delivery_claim_after_open_created_record() async throws {
        let open = await PushMessageDAO.shouldSendOpenEvent(uid: "uid-late")
        XCTAssertTrue(open)

        let delivery = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-late")
        XCTAssertTrue(delivery)

        let repeated = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-late")
        XCTAssertFalse(repeated)

        XCTAssertEqual(sdkCount(entityName: entityName), 1)
    }

    /// - test_5: Only the latest 100 records are kept; the oldest is trimmed
    ///   out and claimed again, the newest stays recorded.
    func test_5_trim_keeps_only_latest_100_uids() async throws {
        for i in 1...101 {
            let shouldSend = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-\(i)")
            XCTAssertTrue(shouldSend, "uid-\(i)")
        }

        XCTAssertEqual(sdkCount(entityName: entityName), 100)

        let oldest = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-1")
        XCTAssertTrue(oldest)

        let newest = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-101")
        XCTAssertFalse(newest)
    }

    // MARK: - Negative

    /// - test_6: Repeated delivery and open claims return false.
    func test_6_repeated_claims_return_false() async throws {
        let delivery = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-dup")
        XCTAssertTrue(delivery)

        let repeatedDelivery = await PushMessageDAO.shouldSendDeliveryEvent(uid: "uid-dup")
        XCTAssertFalse(repeatedDelivery)

        let open = await PushMessageDAO.shouldSendOpenEvent(uid: "uid-open")
        XCTAssertTrue(open)

        let repeatedOpen = await PushMessageDAO.shouldSendOpenEvent(uid: "uid-open")
        XCTAssertFalse(repeatedOpen)
    }

    // MARK: - Helpers

    private func sdkCount(entityName: String) -> Int? {
        guard
            let context = TestCoreDataStack.sdkBackgroundContext(
                containingEntity: entityName
            )
        else { return nil }

        var result: Int?

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            fetchRequest.includesSubentities = true

            do {
                result = try context.count(for: fetchRequest)
            } catch {
                result = nil
            }
        }

        return result
    }

    private func sdkWipe(_ entityNames: [String]) {
        for entityName in entityNames {
            guard
                let context = TestCoreDataStack.sdkBackgroundContext(
                    containingEntity: entityName
                )
            else { continue }

            context.performAndWait {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.includesPropertyValues = false

                if let objects = try? context.fetch(fetchRequest) as? [NSManagedObject] {
                    objects.forEach { context.delete($0) }
                }

                if context.hasChanges {
                    try? context.save()
                }
            }
        }
    }
}
