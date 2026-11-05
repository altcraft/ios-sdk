//
//  DaoClearAllTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
import CoreData
@testable import AltcraftCore
@_spi(_Altcraft) import AltcraftCore
@testable import AltcraftInApp

/**
 * DaoClearAllTests
 *
 * Verifies that "clear-all" DAO operations remove every row with
 * fetch-and-delete — a mechanism compatible with all persistent store
 * types, including the in-memory stores this test bundle runs on
 * (issue #42).
 *
 * Positive scenarios:
 * - test_1: deleteAllInAppSubscribeEntities removes all subscribe rows.
 * - test_2: clearInAppSubStateData removes all sub-state rows.
 * - test_3: deleteAllAuthRequests removes all auth request rows.
 * - test_4: deleteAuthenticationEntity removes all authentication rows.
 *
 */
final class DaoClearAllTests: IsolatedTestCase {

    private let msgSeeded = "Rows must be seeded before the clear"
    private let msgCleared = "All rows must be removed by the clear"

    // MARK: - Positive scenarios

    /// test_1: deleteAllInAppSubscribeEntities removes all subscribe rows
    func test_1_deleteAllInAppSubscribeEntities_removesAllRows() async throws {
        for index in 0..<3 {
            let result = await InAppSubscribeDAO.addInAppSubscribeEntity(
                userTag: "tag-\(index)",
                deviceId: UUID().uuidString,
                acid: "acid-\(index)",
                status: "new",
                sync: false,
                profileFields: nil,
                customFields: nil,
                cats: nil,
                replace: false,
                skipTriggers: false
            )

            guard case .success = result else {
                return XCTFail("Seeding must succeed")
            }
        }

        let before = await countRows(
            entity: InAppConstants.EntityNames.inAppSubscribeEntity,
            container: inAppDatabase.persistentContainer
        )
        XCTAssertEqual(before, 3, msgSeeded)

        await InAppSubscribeDAO.deleteAllInAppSubscribeEntities()

        let after = await countRows(
            entity: InAppConstants.EntityNames.inAppSubscribeEntity,
            container: inAppDatabase.persistentContainer
        )
        XCTAssertEqual(after, 0, msgCleared)
    }

    /// test_2: clearInAppSubStateData removes all sub-state rows
    func test_2_clearInAppSubStateData_removesAllRows() async throws {
        for index in 0..<3 {
            let result = await InAppSubStateDAO.setInAppSubStateEntity(
                userTag: "tag-\(index)",
                status: "subscribed"
            )

            guard case .success = result else {
                return XCTFail("Seeding must succeed")
            }
        }

        let before = await countRows(
            entity: InAppConstants.EntityNames.inAppSubStateEntity,
            container: inAppDatabase.persistentContainer
        )
        XCTAssertEqual(before, 3, msgSeeded)

        await InAppSubStateDAO.clearInAppSubStateData()

        let after = await countRows(
            entity: InAppConstants.EntityNames.inAppSubStateEntity,
            container: inAppDatabase.persistentContainer
        )
        XCTAssertEqual(after, 0, msgCleared)
    }

    /// test_3: deleteAllAuthRequests removes all auth request rows
    func test_3_deleteAllAuthRequests_removesAllRows() async throws {
        let container = CoreDataManager.shared.persistentContainer

        try await seedAuthRequests(count: 3, container: container)

        let before = await countRows(
            entity: Constants.EntityNames.authRequestEntity,
            container: container
        )
        XCTAssertEqual(before, 3, msgSeeded)

        let context = container.newBackgroundContext()
        deleteAllAuthRequests(context: context)

        // The delete runs asynchronously on the context queue; this no-op on
        // the same queue completes only after the deletion is saved.
        _ = try await context.performAsync { () -> Void in }

        let after = await countRows(
            entity: Constants.EntityNames.authRequestEntity,
            container: container
        )
        XCTAssertEqual(after, 0, msgCleared)
    }

    /// test_4: deleteAuthenticationEntity removes all authentication rows
    func test_4_deleteAuthenticationEntity_removesAllRows() async throws {
        let container = CoreDataManager.shared.persistentContainer

        try await seedAuthenticationEntities(count: 2, container: container)

        let before = await countRows(
            entity: Constants.EntityNames.authenticationEntity,
            container: container
        )
        XCTAssertEqual(before, 2, msgSeeded)

        let context = container.newBackgroundContext()
        await deleteAuthenticationEntity(context: context)

        let after = await countRows(
            entity: Constants.EntityNames.authenticationEntity,
            container: container
        )
        XCTAssertEqual(after, 0, msgCleared)
    }

    // MARK: - Helpers

    /// Inserts distinct auth request rows directly, bypassing the DAO's
    /// upsert semantics.
    private func seedAuthRequests(
        count: Int,
        container: NSPersistentContainer
    ) async throws {
        let context = container.newBackgroundContext()
        try await context.performAsync {
            for index in 0..<count {
                let entity = AuthRequestEntity(context: context)
                entity.requestId = "rid-\(index)"
                entity.userTag = "tag-\(index)"
                entity.retryCount = 0
                entity.maxRetryCount = 15
            }
            try context.save()
        }
    }

    /// Inserts distinct authentication rows directly, bypassing the DAO's
    /// upsert semantics.
    private func seedAuthenticationEntities(
        count: Int,
        container: NSPersistentContainer
    ) async throws {
        let context = container.newBackgroundContext()
        try await context.performAsync {
            for index in 0..<count {
                let entity = AuthenticationEntity(context: context)
                entity.currentAcid = "acid-\(index)"
                entity.anonimAcid = "anon-\(index)"
                entity.deviceId = "device-\(index)"
                entity.currentUserTag = "tag-\(index)"
                entity.startAnonSession = Int64(index)
            }
            try context.save()
        }
    }

    /// Counts rows of the named entity in the container's store.
    private func countRows(
        entity: String,
        container: NSPersistentContainer
    ) async -> Int {
        let context = container.newBackgroundContext()
        return (try? await context.performAsync { () -> Int in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            return try context.count(for: request)
        }) ?? -1
    }
}
