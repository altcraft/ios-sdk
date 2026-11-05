//
//  CacheIndexTests.swift
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
 *  - test_1: put stores a URL mapping.
 *  - test_2: get returns stored URL for existing key.
 *  - test_3: get returns nil for non-existing key.
 *  - test_4: put overwrites existing mapping.
 *  - test_5: clear removes all mappings.
 *  - test_6: clear does not affect keys added after clear.
 */
final class CacheIndexTests: XCTestCase {

    private let index = CacheIndex.shared

    private func waitAsync(description: String = "async", timeout: TimeInterval = 2, _ work: @escaping () async throws -> Void) {
        let exp = expectation(description: description)
        Task {
            do {
                try await work()
            } catch {
                XCTFail("\(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: timeout)
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        waitAsync { try await self.index.clear() }
    }

    /// test_1: put stores a URL mapping
    func test_1_put_storesURLMapping() async {
        let key = "https://example.com/img.png"
        let url = URL(fileURLWithPath: "/tmp/img.png")
        await index.put(key, fileURL: url)
        let got = await index.get(key)
        XCTAssertEqual(got, url)
    }

    /// test_2: get returns stored URL for existing key
    func test_2_get_returnsURL_forExistingKey() async {
        let key = "https://a.com/1.png"
        let url = URL(fileURLWithPath: "/tmp/1.png")
        await index.put(key, fileURL: url)
        let retrieved = await index.get(key)
        XCTAssertEqual(retrieved, url)
    }

    /// test_3: get returns nil for non-existing key
    func test_3_get_returnsNil_forNonExistingKey() async {
        let got = await index.get("https://missing.com/x.png")
        XCTAssertNil(got)
    }

    /// test_4: put overwrites existing mapping
    func test_4_put_overwritesExistingMapping() async {
        let key = "https://example.com/img.png"
        let url1 = URL(fileURLWithPath: "/tmp/img1.png")
        let url2 = URL(fileURLWithPath: "/tmp/img2.png")

        await index.put(key, fileURL: url1)
        let got1 = await index.get(key)
        XCTAssertEqual(got1, url1)

        await index.put(key, fileURL: url2)
        let got2 = await index.get(key)
        XCTAssertEqual(got2, url2)
    }

    /// test_5: clear removes all mappings
    func test_5_clear_removesAllMappings() async {
        await index.put("https://a.com/1.png", fileURL: URL(fileURLWithPath: "/tmp/1.png"))
        await index.put("https://b.com/2.png", fileURL: URL(fileURLWithPath: "/tmp/2.png"))

        await index.clear()

        let missingA = await index.get("https://a.com/1.png")
        let missingB = await index.get("https://b.com/2.png")
        XCTAssertNil(missingA)
        XCTAssertNil(missingB)
    }

    /// test_6: clear does not affect keys added after clear
    func test_6_clear_doesNotAffectLaterKeys() async {
        await index.put("https://a.com/1.png", fileURL: URL(fileURLWithPath: "/tmp/1.png"))
        await index.clear()
        await index.put("https://b.com/2.png", fileURL: URL(fileURLWithPath: "/tmp/2.png"))

        let afterClear = await index.get("https://a.com/1.png")
        let afterPut = await index.get("https://b.com/2.png")
        XCTAssertNil(afterClear)
        XCTAssertNotNil(afterPut)
    }
}
