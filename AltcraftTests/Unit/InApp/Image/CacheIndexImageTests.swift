//
//  CacheIndexImageTests.swift
//  Altcraft
//
//  Created by Andrey Pogodin.
//
//  Copyright © 2026 Altcraft. All rights reserved.

import XCTest
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
* CacheIndexTests
*
* Positive scenarios:
* - test_1: Put stores a URL mapping.
* - test_2: Get returns stored URL for existing key.
* - test_3: Get returns nil for non-existing key.
* - test_4: Put overwrites existing mapping.
* - test_5: Clear removes all mappings.
* - test_6: Clear does not affect keys added after clear.
*
*/
final class CacheIndexImageTests: IsolatedTestCase {

    private let index = CacheIndex.shared

    override func setUp() async throws {
        try await super.setUp()
        await index.clear()
    }

    override func tearDown() async throws {
        await index.clear()
        try await super.tearDown()
    }

    /// test_1: Put stores a URL mapping
    func test_1_put_storesURLMapping() async {
        let key = "https://example.com/img.png"
        let url = URL(fileURLWithPath: "/tmp/img.png")

        await index.put(key, fileURL: url)

        let retrieved = await index.get(key)
        XCTAssertEqual(retrieved, url)
    }

    /// test_2: Get returns stored URL for existing key
    func test_2_get_returnsURL_forExistingKey() async {
        let key = "https://a.com/1.png"
        let url = URL(fileURLWithPath: "/tmp/1.png")

        await index.put(key, fileURL: url)

        let retrieved = await index.get(key)
        XCTAssertEqual(retrieved, url)
    }

    /// test_3: Get returns nil for non-existing key
    func test_3_get_returnsNil_forNonExistingKey() async {
        let retrieved = await index.get("https://missing.com/x.png")

        XCTAssertNil(retrieved)
    }

    /// test_4: Put overwrites existing mapping
    func test_4_put_overwritesExistingMapping() async {
        let key = "https://example.com/img.png"
        let url1 = URL(fileURLWithPath: "/tmp/img1.png")
        let url2 = URL(fileURLWithPath: "/tmp/img2.png")

        await index.put(key, fileURL: url1)

        let firstRetrieved = await index.get(key)
        XCTAssertEqual(firstRetrieved, url1)

        await index.put(key, fileURL: url2)

        let secondRetrieved = await index.get(key)
        XCTAssertEqual(secondRetrieved, url2)
    }

    /// test_5: Clear removes all mappings
    func test_5_clear_removesAllMappings() async {
        let firstKey = "https://a.com/1.png"
        let secondKey = "https://b.com/2.png"

        await index.put(
            firstKey,
            fileURL: URL(fileURLWithPath: "/tmp/1.png")
        )

        await index.put(
            secondKey,
            fileURL: URL(fileURLWithPath: "/tmp/2.png")
        )

        await index.clear()

        let firstRetrieved = await index.get(firstKey)
        let secondRetrieved = await index.get(secondKey)

        XCTAssertNil(firstRetrieved)
        XCTAssertNil(secondRetrieved)
    }

    /// test_6: Clear does not affect keys added after clear
    func test_6_clear_doesNotAffectLaterKeys() async {
        let firstKey = "https://a.com/1.png"
        let secondKey = "https://b.com/2.png"

        await index.put(
            firstKey,
            fileURL: URL(fileURLWithPath: "/tmp/1.png")
        )

        await index.clear()

        await index.put(
            secondKey,
            fileURL: URL(fileURLWithPath: "/tmp/2.png")
        )

        let firstRetrieved = await index.get(firstKey)
        let secondRetrieved = await index.get(secondKey)

        XCTAssertNil(firstRetrieved)
        XCTAssertNotNil(secondRetrieved)
    }
}
